package net.firewood.app.security

import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Build
import android.os.ParcelUuid
import io.flutter.plugin.common.EventChannel
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Native Android BLE P2P Manager for Firewood credential transfer (Android ↔ Android).
 *
 * Implements both the advertiser (receiver) and scanner/connector (sender) roles
 * using Android's built-in Bluetooth LE APIs – no external plugin required.
 *
 * Architecture:
 *  - One GATT service with UUID FIREWOOD_SERVICE_UUID
 *  - One characteristic with UUID FIREWOOD_CHAR_UUID (WRITE + NOTIFY)
 *  - Advertiser exposes the service; scanner discovers it
 *  - After GATT connection, both sides do X25519 handshake through Dart (P2PCryptoSession)
 *  - Encrypted payload transfers as raw bytes over the GATT characteristic
 *
 * Protocol:
 *  1. Receiver calls startAdvertise() – BLE starts advertising the Firewood service
 *  2. Sender calls startScan() – BLE scans for Firewood service UUID
 *  3. On discovery, sender calls connectToDevice()
 *  4. GATT connection established → LE **bonding** is started immediately
 *     (V-012): the characteristic only accepts writes on an encrypted link,
 *     so transfers wait for the pairing handshake to complete
 *  5. Dart layer performs X25519 handshake through this BLE pipe
 *  6. Encrypted wire packets flow over the BLE GATT characteristic
 *  7. On completion, both sides call disconnect()
 *
 * BLE MTU: Negotiated up to 512 bytes. Large payloads are chunked by the Dart layer.
 */
class BleP2PManager(
    private val context: Context
) {
    companion object {
        val FIREWOOD_SERVICE_UUID: UUID =
            UUID.fromString("0000ff00-0000-1000-8000-00805f9b34fb")
        val FIREWOOD_CHAR_UUID: UUID =
            UUID.fromString("0000ff01-0000-1000-8000-00805f9b34fb")
        val CCCD_UUID: UUID =
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

        private const val SCAN_PERIOD_MS = 30000L // 30 second scan window

        // Event channel names (Flutter listens on these)
        const val EVENT_BLE_DISCOVERY = "com.firewood.ble/discovery"
        const val EVENT_BLE_CONNECTION = "com.firewood.ble/connection"
        const val EVENT_BLE_DATA = "com.firewood.ble/data"
    }

    private val bluetoothManager: BluetoothManager? by lazy {
        try {
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        } catch (_: Exception) {
            null
        }
    }
    private val bluetoothAdapter: BluetoothAdapter?
        get() = try {
            bluetoothManager?.adapter
        } catch (_: Exception) {
            null
        }

    // --- BLE Server (Advertiser / Receiver role) ---
    private var gattServer: BluetoothGattServer? = null
    private var isAdvertising = false

    // --- BLE Client (Scanner / Sender role) ---
    private var bleScanner: BluetoothLeScanner? = null
        get() = field ?: try {
            bluetoothAdapter?.bluetoothLeScanner
        } catch (_: Exception) {
            null
        }
    private var scanCallback: ScanCallback? = null
    private var isScanning = false

    // Active GATT connections (device address → BluetoothGatt)
    private val activeGattConnections = ConcurrentHashMap<String, BluetoothGatt>()

    // Event sinks for Flutter communication
    private var discoverySink: EventChannel.EventSink? = null
    private var connectionSink: EventChannel.EventSink? = null
    private var dataSink: EventChannel.EventSink? = null

    // --- Event Sink Registration ---

    fun setDiscoverySink(sink: EventChannel.EventSink?) {
        discoverySink = sink
    }

    fun setConnectionSink(sink: EventChannel.EventSink?) {
        connectionSink = sink
    }

    fun setDataSink(sink: EventChannel.EventSink?) {
        dataSink = sink
    }

    // --- Advertiser (Receiver) ---

    @SuppressLint("MissingPermission")
    fun startAdvertise(): Boolean {
        val adapter = bluetoothAdapter ?: return false
        if (!adapter.isEnabled) return false

        try {
            val manager = bluetoothManager ?: return false
            val server = manager.openGattServer(context, object : BluetoothGattServerCallback() {
                override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
                    when (newState) {
                        BluetoothProfile.STATE_CONNECTED -> {
                            // V-012: require LE bonding. The characteristic's
                            // PERMISSION_*_ENCRYPTED only passes on an encrypted
                            // link, so pairing starts the moment a peer attaches.
                            if (device.bondState == BluetoothDevice.BOND_NONE) {
                                try {
                                    device.createBond()
                                } catch (_: SecurityException) {
                                }
                            }
                            connectionSink?.success(mapOf(
                                "event" to "connected",
                                "deviceId" to device.address,
                                "deviceName" to (device.name ?: "Unknown"),
                                "role" to "receiver"
                            ))
                        }
                        BluetoothProfile.STATE_DISCONNECTED -> {
                            connectionSink?.success(mapOf(
                                "event" to "disconnected",
                                "deviceId" to device.address
                            ))
                            activeGattConnections.remove(device.address)
                        }
                    }
                }

                override fun onCharacteristicWriteRequest(
                    device: BluetoothDevice,
                    requestId: Int,
                    characteristic: BluetoothGattCharacteristic,
                    preparedWrite: Boolean,
                    responseNeeded: Boolean,
                    offset: Int,
                    value: ByteArray
                ) {
                    if (characteristic.uuid == FIREWOOD_CHAR_UUID) {
                        dataSink?.success(mapOf(
                            "deviceId" to device.address,
                            "data" to value
                        ))
                        if (responseNeeded) {
                            gattServer?.sendResponse(
                                device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null
                            )
                        }
                    }
                }

                // V-012: no onCharacteristicReadRequest handler exists — reads
                // are not part of the protocol. The characteristic declares no
                // PROPERTY_READ/PERMISSION_READ, so the stack rejects them
                // outright; the old handler returned the last app-layer frame
                // to any peer that asked.

                override fun onNotificationSent(device: BluetoothDevice, status: Int) {
                    // Ignored for now – notifications are fire-and-forget
                }
            })

            // Build the GATT service.
            // V-012: writes require an ENCRYPTED (bonded) link
            // (PERMISSION_WRITE_ENCRYPTED) — an unbonded peer cannot inject
            // frames into the parser at all. Reads are dropped entirely
            // (no PROPERTY_READ/PERMISSION_READ): the protocol is write +
            // notify only, and the old readable characteristic leaked the
            // last frame to anyone in range.
            val char = BluetoothGattCharacteristic(
                FIREWOOD_CHAR_UUID,
                BluetoothGattCharacteristic.PROPERTY_WRITE or
                BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                BluetoothGattCharacteristic.PERMISSION_WRITE_ENCRYPTED
            )

            val service = BluetoothGattService(
                FIREWOOD_SERVICE_UUID,
                BluetoothGattService.SERVICE_TYPE_PRIMARY
            )
            service.addCharacteristic(char)
            server.addService(service)

            gattServer = server

            // Start advertising
            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
                .setConnectable(true)
                .build()

            val data = AdvertiseData.Builder()
                .setIncludeDeviceName(false)
                .addServiceUuid(ParcelUuid(FIREWOOD_SERVICE_UUID))
                .build()

            val scanResponse = AdvertiseData.Builder()
                .setIncludeDeviceName(true)
                .build()

            val advertiser = adapter.bluetoothLeAdvertiser
            if (advertiser == null) {
                connectionSink?.error("ADVERTISE_ERROR", "Bluetooth LE Advertiser not available on this device", null)
                return false
            }

            advertiser.startAdvertising(settings, data, scanResponse, object : AdvertiseCallback() {
                override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                    isAdvertising = true
                }

                override fun onStartFailure(errorCode: Int) {
                    isAdvertising = false
                    connectionSink?.error("ADVERTISE_FAILED", "BLE advertising failed with code $errorCode", null)
                }
            })

            isAdvertising = true
            return true
        } catch (e: SecurityException) {
            connectionSink?.error("PERMISSION_DENIED", "Bluetooth permission denied", e.message)
            return false
        } catch (e: Exception) {
            connectionSink?.error("ADVERTISE_ERROR", "Failed to start BLE advertising", e.message)
            return false
        }
    }

    @SuppressLint("MissingPermission")
    fun stopAdvertise() {
        try {
            bluetoothAdapter?.bluetoothLeAdvertiser?.stopAdvertising(object : AdvertiseCallback() {})
        } catch (_: SecurityException) { }
        gattServer?.close()
        gattServer = null
        isAdvertising = false
    }

    // --- Scanner (Sender) ---

    @SuppressLint("MissingPermission")
    fun startScan(): Boolean {
        val adapter = bluetoothAdapter ?: return false
        if (!adapter.isEnabled) return false
        if (isScanning) return true

        bleScanner = adapter.bluetoothLeScanner
        val scanner = bleScanner ?: return false

        try {
            scanCallback = object : ScanCallback() {
                override fun onScanResult(callbackType: Int, result: ScanResult) {
                    val device = result.device
                    val scanRecord = result.scanRecord
                    val name = scanRecord?.deviceName ?: device.name ?: "Firewood Device"

                    discoverySink?.success(mapOf(
                        "event" to "discovered",
                        "deviceId" to device.address,
                        "deviceName" to name,
                        "rssi" to result.rssi
                    ))
                }

                override fun onScanFailed(errorCode: Int) {
                    discoverySink?.error("SCAN_FAILED", "BLE scan failed with code $errorCode", null)
                }
            }

            val filter = ScanFilter.Builder()
                .setServiceUuid(ParcelUuid(FIREWOOD_SERVICE_UUID))
                .build()

            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build()

            scanner.startScan(listOf(filter), settings, scanCallback)
            isScanning = true
            return true
        } catch (e: SecurityException) {
            discoverySink?.error("PERMISSION_DENIED", "Bluetooth scan permission denied", e.message)
            return false
        } catch (e: Exception) {
            discoverySink?.error("SCAN_ERROR", "Failed to start BLE scan", e.message)
            return false
        }
    }

    @SuppressLint("MissingPermission")
    fun stopScan() {
        try {
            scanCallback?.let { bleScanner?.stopScan(it) }
        } catch (_: SecurityException) { }
        scanCallback = null
        isScanning = false
    }

    // --- GATT Connection (Sender connects to discovered device) ---

    @SuppressLint("MissingPermission")
    fun connectToDevice(deviceAddress: String): Boolean {
        val adapter = bluetoothAdapter ?: return false
        if (!adapter.isEnabled) return false

        val device = adapter.getRemoteDevice(deviceAddress) ?: return false

        try {
            val gatt = device.connectGatt(context, false, object : BluetoothGattCallback() {
                override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                    when (newState) {
                        BluetoothProfile.STATE_CONNECTED -> {
                            if (status == BluetoothGatt.GATT_SUCCESS) {
                                // V-012: bond before any transfer — the remote
                                // characteristic rejects writes until the link
                                // is encrypted.
                                if (gatt.device.bondState == BluetoothDevice.BOND_NONE) {
                                    try {
                                        gatt.device.createBond()
                                    } catch (_: SecurityException) {
                                    }
                                }
                                // Request MTU upgrade for larger payloads
                                gatt.requestMtu(512)
                            }
                        }
                        BluetoothProfile.STATE_DISCONNECTED -> {
                            connectionSink?.success(mapOf(
                                "event" to "disconnected",
                                "deviceId" to deviceAddress
                            ))
                            activeGattConnections.remove(deviceAddress)
                            gatt.close()
                        }
                    }
                }

                override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        // Enable notifications on Firewood characteristic so receiver can talk back
                        val service = gatt.getService(FIREWOOD_SERVICE_UUID)
                        val characteristic = service?.getCharacteristic(FIREWOOD_CHAR_UUID)
                        if (characteristic != null) {
                            gatt.setCharacteristicNotification(characteristic, true)
                            val cccd = characteristic.getDescriptor(CCCD_UUID)
                            if (cccd != null) {
                                cccd.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                                gatt.writeDescriptor(cccd)
                            }
                        }
                        connectionSink?.success(mapOf(
                            "event" to "connected",
                            "deviceId" to deviceAddress,
                            "deviceName" to (device.name ?: "Unknown"),
                            "role" to "sender"
                        ))
                    } else {
                        connectionSink?.error("GATT_ERROR",
                            "Failed to discover services on $deviceAddress", status.toString())
                        gatt.disconnect()
                    }
                }

                override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
                    // MTU negotiated – discover services
                    gatt.discoverServices()
                }

                override fun onCharacteristicChanged(
                    gatt: BluetoothGatt,
                    characteristic: BluetoothGattCharacteristic
                ) {
                    if (characteristic.uuid == FIREWOOD_CHAR_UUID) {
                        characteristic.value?.let { value ->
                            dataSink?.success(mapOf(
                                "deviceId" to deviceAddress,
                                "data" to value
                            ))
                        }
                    }
                }

                override fun onCharacteristicWrite(
                    gatt: BluetoothGatt,
                    characteristic: BluetoothGattCharacteristic,
                    status: Int
                ) {
                    // Write acknowledged – no action needed
                }
            }, BluetoothDevice.TRANSPORT_LE)

            activeGattConnections[deviceAddress] = gatt
            return true
        } catch (e: SecurityException) {
            connectionSink?.error("PERMISSION_DENIED", "Bluetooth connect permission denied", e.message)
            return false
        } catch (e: Exception) {
            connectionSink?.error("CONNECT_ERROR", "Failed to connect to $deviceAddress", e.message)
            return false
        }
    }

    /**
     * Sends [data] to a connected GATT device via characteristic write.
     * If the device is the GATT server (i.e., we're connected as client),
     * we write to the characteristic. If we are the GATT server (advertiser),
     * we send a notification to the connected client.
     *
     * For large payloads, the Dart layer chunks the data into MTU-sized pieces.
     */
    @SuppressLint("MissingPermission")
    fun sendData(deviceAddress: String, data: ByteArray): Boolean {
        // V-012: fail closed — no frame moves over an unbonded link. The
        // client-write branch is double-covered by PERMISSION_WRITE_ENCRYPTED
        // on the characteristic; notifications are NOT permission-checked by
        // ATT, so the server/notify branch needs this gate explicitly.
        // Throws so the method channel can surface the reason to Dart.
        val peer = try {
            activeGattConnections[deviceAddress]?.device
                ?: bluetoothAdapter?.getRemoteDevice(deviceAddress)
        } catch (_: Exception) {
            null
        }
        if (peer == null) {
            dataSink?.error("GATT_ERROR", "No connection to $deviceAddress", null)
            return false
        }
        if (peer.bondState != BluetoothDevice.BOND_BONDED) {
            throw IllegalStateException(
                "Pairing required — accept the pairing request on both devices, then retry the transfer"
            )
        }

        // Check if we are the GATT client (connected to a server device)
        val gattClient = activeGattConnections[deviceAddress]
        if (gattClient != null) {
            // We are the client – write to the Firewood characteristic
            val service = gattClient.getService(FIREWOOD_SERVICE_UUID)
            if (service == null) {
                // Service not yet discovered; queue or fail
                dataSink?.error("GATT_ERROR", "Firewood service not discovered", null)
                return false
            }
            val characteristic = service.getCharacteristic(FIREWOOD_CHAR_UUID)
            if (characteristic == null) {
                dataSink?.error("GATT_ERROR", "Firewood characteristic not found", null)
                return false
            }
            val success = characteristic.setValue(data)
            if (!success) return false
            return gattClient.writeCharacteristic(characteristic)
        }

        // Check if we are the GATT server (the device connected to us)
        val device = bluetoothAdapter?.getRemoteDevice(deviceAddress) ?: return false
        try {
            val service = gattServer?.getService(FIREWOOD_SERVICE_UUID)
            if (service != null) {
                val characteristic = service.getCharacteristic(FIREWOOD_CHAR_UUID)
                if (characteristic != null) {
                    characteristic.value = data
                    val notifySuccess = gattServer?.notifyCharacteristicChanged(
                        device, characteristic, false
                    ) ?: false
                    return notifySuccess
                }
            }
        } catch (e: SecurityException) {
            return false
        }

        return false
    }

    /**
     * Disconnects from [deviceAddress] and cleans up the GATT connection.
     */
    @SuppressLint("MissingPermission")
    fun disconnectDevice(deviceAddress: String) {
        try {
            activeGattConnections[deviceAddress]?.disconnect()
            activeGattConnections[deviceAddress]?.close()
        } catch (_: SecurityException) { }
        activeGattConnections.remove(deviceAddress)
    }

    /**
     * Stops all BLE activity (advertising, scanning, all connections).
     */
    fun shutdown() {
        stopAdvertise()
        stopScan()
        activeGattConnections.values.forEach { gatt ->
            try {
                gatt.disconnect()
                gatt.close()
            } catch (_: Exception) { }
        }
        activeGattConnections.clear()
    }
}

package net.firewood.app.security

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter ↔ Native bridge for all security-sensitive operations and BLE P2P.
 *
 * MethodChannel "com.firewood.vault_security" handles:
 *  - Biometric key wrapping/unwrapping (replaces raw FlutterSecureStorage)
 *  - Rate-limited unlock attempt tracking
 *  - Environment integrity check
 *  - Secure clipboard operations
 *  - Screen capture flag toggling
 *  - BLE P2P: startAdvertise, startScan, connectDevice, sendData, disconnectDevice, shutdownBle
 *
 * EventChannels for BLE P2P async events:
 *  - com.firewood.ble/discovery → device discovered during scan
 *  - com.firewood.ble/connection → GATT connected / disconnected
 *  - com.firewood.ble/data → characteristic data received
 */
class SecureMethodChannel(
    private val activity: Activity,
    private val flutterEngine: FlutterEngine
) {
    companion object {
        const val CHANNEL_NAME = "com.firewood.vault_security"
    }

    private val keystoreManager = SecureKeystoreManager()
    private val bleManager = BleP2PManager(activity)
    private val mainHandler = Handler(Looper.getMainLooper())

    fun register() {
        // --- MethodChannel for RPC-style calls ---
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            mainHandler.post {
                handleMethodCall(call, result, activity)
            }
        }

        // --- EventChannels for BLE async events ---
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BleP2PManager.EVENT_BLE_DISCOVERY
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                bleManager.setDiscoverySink(sink)
            }
            override fun onCancel(args: Any?) {
                bleManager.setDiscoverySink(null)
            }
        })

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BleP2PManager.EVENT_BLE_CONNECTION
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                bleManager.setConnectionSink(sink)
            }
            override fun onCancel(args: Any?) {
                bleManager.setConnectionSink(null)
            }
        })

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BleP2PManager.EVENT_BLE_DATA
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                bleManager.setDataSink(sink)
            }
            override fun onCancel(args: Any?) {
                bleManager.setDataSink(null)
            }
        })
    }

    private fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        try {
            when (call.method) {

                // --- Biometric Key Wrapping (Fixes CRITICAL P1) ---

                "createWrappingKey" -> {
                    val requireAuth = call.argument<Boolean>("requireUserAuth") ?: true
                    val invalidateOnEnroll = call.argument<Boolean>("invalidateOnEnrollment") ?: true
                    keystoreManager.createWrappingKey(requireAuth, invalidateOnEnroll)
                    SecurePreferences.setBiometricEnabled(context, true)
                    result.success(true)
                }

                "wrapMasterPassword" -> {
                    val password = call.argument<String>("password")
                        ?: throw IllegalArgumentException("Missing 'password' argument")
                    val passwordBytes = password.toByteArray(Charsets.UTF_8)
                    try {
                        val wrappedBlob = keystoreManager.wrapData(passwordBytes)
                        SecurePreferences.storeWrappedPassword(context, wrappedBlob)
                        result.success(true)
                    } finally {
                        MemoryGuard.zeroize(passwordBytes)
                    }
                }

                "unwrapMasterPassword" -> {
                    val wrappedBlob = SecurePreferences.getWrappedPassword(context)
                        ?: run {
                            result.error("NO_WRAPPED_KEY", "No wrapped password found", null)
                            return
                        }
                    try {
                        val decryptedBytes = keystoreManager.unwrapData(wrappedBlob)
                        val password = String(decryptedBytes, Charsets.UTF_8)
                        MemoryGuard.zeroize(decryptedBytes)
                        result.success(password)
                    } catch (e: javax.crypto.AEADBadTagException) {
                        result.error("TAMPERED_DATA", "Wrapped data integrity check failed", null)
                    }
                }

                "hasWrappingKey" -> result.success(keystoreManager.hasWrappingKey())

                "deleteWrappingKey" -> {
                    keystoreManager.deleteWrappingKey()
                    SecurePreferences.clearWrappedPassword(context)
                    SecurePreferences.setBiometricEnabled(context, false)
                    result.success(true)
                }

                // --- Rate Limiting (Fixes MEDIUM P3) ---

                "recordFailedUnlockAttempt" -> {
                    val count = SecurePreferences.recordFailedAttempt(context)
                    val lockoutMs = SecurePreferences.getLockoutRemainingMs(context)
                    result.success(mapOf(
                        "attemptCount" to count,
                        "lockoutRemainingMs" to lockoutMs,
                        "isLockedOut" to (lockoutMs > 0)
                    ))
                }

                "getLockoutStatus" -> {
                    val lockoutMs = SecurePreferences.getLockoutRemainingMs(context)
                    val count = SecurePreferences.getFailedAttemptCount(context)
                    result.success(mapOf(
                        "attemptCount" to count,
                        "lockoutRemainingMs" to lockoutMs,
                        "isLockedOut" to (lockoutMs > 0)
                    ))
                }

                "resetFailedAttempts" -> {
                    SecurePreferences.resetFailedAttempts(context)
                    result.success(true)
                }

                // --- Screen Capture Control ---

                "enableSecureFlag" -> {
                    activity.runOnUiThread { AntiLeakActivityManager.reapplySecureFlags(activity) }
                    result.success(true)
                }

                "disableSecureFlag" -> {
                    activity.runOnUiThread { AntiLeakActivityManager.temporarilyAllowScreenshots(activity) }
                    result.success(true)
                }

                // --- Environment Integrity ---

                "auditEnvironment" -> {
                    val audit = AntiLeakActivityManager.auditEnvironment(context)
                    result.success(mapOf(
                        "isCompromised" to audit.isCompromised,
                        "findings" to audit.findings
                    ))
                }

                // --- Secure Clipboard ---

                "clearClipboard" -> {
                    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE)
                        as? android.content.ClipboardManager
                    clipboard?.setPrimaryClip(android.content.ClipData.newPlainText("", ""))
                    result.success(true)
                }

                // --- Radio State Checks (WiFi / Bluetooth) ---

                "checkWifiEnabled" -> {
                    val wifiManager = context.applicationContext
                        .getSystemService(Context.WIFI_SERVICE) as? android.net.wifi.WifiManager
                    val enabled = wifiManager?.isWifiEnabled ?: false
                    result.success(enabled)
                }

                "checkBluetoothEnabled" -> {
                    val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE)
                        as? android.bluetooth.BluetoothManager
                    val adapter = btManager?.adapter
                    val enabled = adapter?.isEnabled ?: false
                    result.success(enabled)
                }

                // --- BLE P2P (Android ↔ Android) ---

                "bleStartAdvertise" -> {
                    val ok = bleManager.startAdvertise()
                    result.success(ok)
                }

                "bleStopAdvertise" -> {
                    bleManager.stopAdvertise()
                    result.success(true)
                }

                "bleStartScan" -> {
                    val ok = bleManager.startScan()
                    result.success(ok)
                }

                "bleStopScan" -> {
                    bleManager.stopScan()
                    result.success(true)
                }

                "bleConnectDevice" -> {
                    val address = call.argument<String>("deviceAddress")
                        ?: throw IllegalArgumentException("Missing 'deviceAddress' argument")
                    val ok = bleManager.connectToDevice(address)
                    result.success(ok)
                }

                "bleSendData" -> {
                    val address = call.argument<String>("deviceAddress")
                        ?: throw IllegalArgumentException("Missing 'deviceAddress'")
                    val data = call.argument<ByteArray>("data")
                        ?: throw IllegalArgumentException("Missing 'data'")
                    val ok = bleManager.sendData(address, data)
                    result.success(ok)
                }

                "bleDisconnectDevice" -> {
                    val address = call.argument<String>("deviceAddress")
                        ?: throw IllegalArgumentException("Missing 'deviceAddress'")
                    bleManager.disconnectDevice(address)
                    result.success(true)
                }

                "bleShutdown" -> {
                    bleManager.shutdown()
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        } catch (e: SecurityException) {
            result.error("AUTH_FAILED", "Biometric authentication failed or was cancelled", e.message)
        } catch (e: IllegalArgumentException) {
            result.error("INVALID_ARGUMENT", e.message, null)
        } catch (e: Exception) {
            result.error("INTERNAL_ERROR", "Unexpected security error", e.message)
        }
    }
}

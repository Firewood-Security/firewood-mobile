package net.firewood.app.security

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import net.firewood.app.autofill.AutofillSecureStore
import net.firewood.app.notification.FirewoodNotificationManager

/**
 * Flutter ↔ Native bridge for all security-sensitive operations, BLE P2P, Autofill, and Notifications.
 */
class SecureMethodChannel(
    private val activity: Activity,
    private val flutterEngine: FlutterEngine
) {
    companion object {
        const val CHANNEL_NAME = "com.firewood.vault_security"
        private const val REQUEST_NOTIFICATION_PERMISSION = 4407
    }

    private val keystoreManager = SecureKeystoreManager()
    private val bleManager = BleP2PManager(activity)
    private val notificationManager = FirewoodNotificationManager(activity)
    private val mainHandler = Handler(Looper.getMainLooper())

    /// Pending result for the POST_NOTIFICATIONS system dialog — completed by
    /// [onRequestPermissionsResult] when the user answers it.
    private var notificationPermissionResult: MethodChannel.Result? = null

    /** Called from MainActivity.onRequestPermissionsResult, our code only. */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_NOTIFICATION_PERMISSION) return
        val granted =
            grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
        notificationPermissionResult?.success(granted)
        notificationPermissionResult = null
    }

    /** Completes any still-pending permission dialog so a Dart-side await
     *  can never hang when the activity goes away. */
    fun detach() {
        notificationPermissionResult?.success(false)
        notificationPermissionResult = null
    }

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
                    // V-016: auth binding is NOT caller-controllable. Dart-supplied
                    // flags are ignored — any in-app code (incl. a compromised
                    // plugin) must never be able to mint an unbound wrapping key
                    // and re-wrap the master password for biometric-less unwrap.
                    keystoreManager.createWrappingKey()
                    SecurePreferences.setBiometricEnabled(context, true)
                    result.success(true)
                }

                "wrapMasterPassword" -> {
                    val password = call.argument<String>("password")
                        ?: throw IllegalArgumentException("Missing 'password' argument")
                    val passwordBytes = password.toByteArray(Charsets.UTF_8)
                    val swNanos = android.os.SystemClock.elapsedRealtimeNanos()
                    try {
                        val wrappedBlob = keystoreManager.wrapData(passwordBytes)
                        SecurePreferences.storeWrappedPassword(context, wrappedBlob)
                        val elapsedUs = (android.os.SystemClock.elapsedRealtimeNanos() - swNanos) / 1000
                        android.util.Log.d("CRYPTO-NATIVE", "op=wrapMasterPassword us=$elapsedUs blob_len=${wrappedBlob.size} ok=true")
                        result.success(true)
                    } catch (e: Exception) {
                        val elapsedUs = (android.os.SystemClock.elapsedRealtimeNanos() - swNanos) / 1000
                        android.util.Log.d("CRYPTO-NATIVE", "op=wrapMasterPassword us=$elapsedUs ok=false err=${e.javaClass.simpleName}")
                        throw e
                    } finally {
                        MemoryGuard.zeroize(passwordBytes)
                    }
                }

                "unwrapMasterPassword" -> {
                    // V-026: the native unlock path enforces the rate limit
                    // itself — a compromised/buggy Dart layer cannot reach
                    // the Keystore unwrap while a lockout is active.
                    val activeLockoutMs = SecurePreferences.getLockoutRemainingMs(context)
                    if (activeLockoutMs > 0) {
                        android.util.Log.d("CRYPTO-NATIVE", "op=unwrapMasterPassword ok=false err=LOCKED_OUT remaining_ms=$activeLockoutMs")
                        result.error(
                            "LOCKED_OUT",
                            "Too many failed attempts. Wait ${activeLockoutMs / 1000}s.",
                            activeLockoutMs
                        )
                        return
                    }
                    val wrappedBlob = SecurePreferences.getWrappedPassword(context)
                        ?: run {
                            android.util.Log.d("CRYPTO-NATIVE", "op=unwrapMasterPassword ok=false err=NO_WRAPPED_KEY")
                            result.error("NO_WRAPPED_KEY", "No wrapped password found", null)
                            return
                        }
                    val swNanos = android.os.SystemClock.elapsedRealtimeNanos()
                    try {
                        val decryptedBytes = keystoreManager.unwrapData(wrappedBlob)
                        val password = String(decryptedBytes, Charsets.UTF_8)
                        MemoryGuard.zeroize(decryptedBytes)
                        val elapsedUs = (android.os.SystemClock.elapsedRealtimeNanos() - swNanos) / 1000
                        android.util.Log.d("CRYPTO-NATIVE", "op=unwrapMasterPassword us=$elapsedUs blob_len=${wrappedBlob.size} ok=true")
                        // V-026: the ONLY counter reset, and it is proof-based —
                        // the Keystore just authenticated the user to unwrap.
                        SecurePreferences.resetFailedAttempts(context)
                        result.success(password)
                    } catch (e: javax.crypto.AEADBadTagException) {
                        val elapsedUs = (android.os.SystemClock.elapsedRealtimeNanos() - swNanos) / 1000
                        android.util.Log.d("CRYPTO-NATIVE", "op=unwrapMasterPassword us=$elapsedUs ok=false err=TAMPERED_DATA")
                        result.error("TAMPERED_DATA", "Wrapped data integrity check failed", null)
                    }
                }

                "hasWrappingKey" -> result.success(keystoreManager.hasWrappingKey())

                // Debug-only: detect wireless debugging (ADB over Wi-Fi).
                // Used to gate crypto metrics logging. Returns false on
                // Android < 11 (no adb_wifi_enabled setting).
                "isWirelessDebugging" -> {
                    val enabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        try {
                            Settings.Global.getInt(
                                context.contentResolver, "adb_wifi_enabled", 0
                            ) == 1
                        } catch (_: Exception) { false }
                    } else { false }
                    result.success(enabled)
                }

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

                // V-026: no "resetFailedAttempts" method exists here anymore.
                // It was callable from Dart without any proof of success; the
                // counter now clears only inside the successful unwrap path
                // above (Keystore-authenticated proof).

                // --- Screen Capture Control ---

                "enableSecureFlag" -> {
                    activity.runOnUiThread { AntiLeakActivityManager.reapplySecureFlags(activity) }
                    result.success(true)
                }

                "disableSecureFlag" -> {
                    // V-019: FLAG_SECURE is window-wide; dropping it is only
                    // permitted when the user's stored screenshot policy
                    // allows capture — the Settings toggle writes
                    // `flutter.allow_screenshots` before calling this. Any
                    // other caller (the old AirShare QR dance did this
                    // unconditionally) is refused, so no in-app code can
                    // expose what sits BEHIND an open sheet. Read via the
                    // raw map: shared_preferences versions have stored this
                    // value as Boolean or as String "true"/"false".
                    val prefs = context.getSharedPreferences(
                        "FlutterSharedPreferences", Context.MODE_PRIVATE
                    )
                    val allowed = when (val v = prefs.all["flutter.allow_screenshots"]) {
                        is Boolean -> v
                        is String -> v == "true"
                        else -> false
                    }
                    if (!allowed) {
                        result.error(
                            "POLICY_DENIED",
                            "Screenshot policy does not allow capture",
                            null
                        )
                    } else {
                        activity.runOnUiThread {
                            AntiLeakActivityManager.temporarilyAllowScreenshots(activity)
                        }
                        result.success(true)
                    }
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

                "setClipboard" -> {
                    val text = call.argument<String>("text")
                        ?: throw IllegalArgumentException("Missing 'text'")
                    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE)
                        as? android.content.ClipboardManager
                    if (clipboard == null) {
                        result.error("INTERNAL_ERROR", "Clipboard unavailable", null)
                    } else {
                        val clip = android.content.ClipData.newPlainText("Firewood", text)
                        // V-017: mark every secret clip as sensitive so Android
                        // masks it in the clipboard preview / assistant surfaces.
                        // ClipDescription extras are API 24+ (== minSdk).
                        clip.description.extras = android.os.PersistableBundle().apply {
                            putBoolean(
                                android.content.ClipDescription.EXTRA_IS_SENSITIVE,
                                true
                            )
                        }
                        clipboard.setPrimaryClip(clip)
                        result.success(true)
                    }
                }

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
                    val btManager = try {
                        context.getSystemService(Context.BLUETOOTH_SERVICE) as? android.bluetooth.BluetoothManager
                    } catch (_: Exception) { null }
                    val adapter = try { btManager?.adapter } catch (_: Exception) { null }
                    val enabled = try { adapter?.isEnabled ?: false } catch (_: Exception) { false }
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
                    try {
                        val ok = bleManager.sendData(address, data)
                        result.success(ok)
                    } catch (e: IllegalStateException) {
                        // V-012: the link is not bonded yet — fail closed with
                        // the actionable pairing message instead of a generic
                        // internal error.
                        result.error("BONDING_REQUIRED", e.message, null)
                    }
                }

                // --- V-013: hand the hash-verified update APK to the installer ---

                "installUpdate" -> {
                    val path = call.argument<String>("path")
                        ?: throw IllegalArgumentException("Missing 'path'")
                    val file = java.io.File(path)
                    // Containment: only files this app owns, inside its cache
                    // (the in-app download lands in <cache>/update/), resolved
                    // through canonical paths so ../ cannot escape.
                    val cache = context.cacheDir.canonicalFile
                    val target = if (file.isFile) file.canonicalFile else null
                    if (target == null ||
                        !target.path.startsWith(cache.path + java.io.File.separator)
                    ) {
                        throw IllegalArgumentException("Update file is not inside the app cache")
                    }
                    if (!target.name.endsWith(".apk")) {
                        throw IllegalArgumentException("Update file is not an APK")
                    }
                    // content:// only (file:// URIs are blocked since API 24).
                    // The bytes were SHA-256-verified in Dart against the
                    // signed manifest before this call was made.
                    val uri = androidx.core.content.FileProvider.getUriForFile(
                        context, "${context.packageName}.fileprovider", target
                    )
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_ACTIVITY_NEW_TASK
                        )
                    }
                    context.startActivity(intent)
                    result.success(true)
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

                // --- Notifications ---

                "hasNotificationPermission" -> {
                    result.success(notificationManager.hasPermission())
                }

                // Android 13+ runtime permission for POST_NOTIFICATIONS. The
                // app-level pref alone never shows anything on API 33+ — the
                // OS dialog must be requested, so the settings switch awaits
                // the user's actual answer here (fail closed on denial).
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val already = ContextCompat.checkSelfPermission(
                            activity,
                            Manifest.permission.POST_NOTIFICATIONS
                        ) == PackageManager.PERMISSION_GRANTED
                        when {
                            already -> result.success(true)
                            notificationPermissionResult != null ->
                                result.success(false) // dialog already up
                            else -> {
                                notificationPermissionResult = result
                                ActivityCompat.requestPermissions(
                                    activity,
                                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                    REQUEST_NOTIFICATION_PERMISSION
                                )
                            }
                        }
                    } else {
                        // Pre-13 has no runtime permission; the OS master
                        // notifications toggle is the gate — report it.
                        result.success(notificationManager.hasPermission())
                    }
                }

                "showNotification" -> {
                    val id = call.argument<Int>("id") ?: 1
                    val channelId = call.argument<String>("channelId") ?: FirewoodNotificationManager.CHANNEL_ALERTS
                    val title = call.argument<String>("title") ?: "Firewood"
                    val message = call.argument<String>("message") ?: ""
                    val ok = notificationManager.showNotification(id, channelId, title, message)
                    result.success(ok)
                }

                "cancelNotification" -> {
                    val id = call.argument<Int>("id") ?: 1
                    notificationManager.cancelNotification(id)
                    result.success(true)
                }

                "cancelAllNotifications" -> {
                    notificationManager.cancelAllNotifications()
                    result.success(true)
                }

                // --- Autofill (Browser & App Forms) ---

                "isAutofillSupported" -> {
                    result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                }

                "isAutofillEnabled" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val afm = activity.getSystemService(android.view.autofill.AutofillManager::class.java)
                        result.success(afm?.hasEnabledAutofillServices() == true)
                    } else {
                        result.success(false)
                    }
                }

                "openAutofillSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE).apply {
                                data = Uri.parse("package:${activity.packageName}")
                            }
                            activity.startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            try {
                                val fallback = Intent(Settings.ACTION_SETTINGS)
                                activity.startActivity(fallback)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("AUTOFILL_SETTINGS_ERROR", e.message, null)
                            }
                        }
                    } else {
                        result.success(false)
                    }
                }

                "syncAutofillStore" -> {
                    val json = call.argument<String>("json") ?: "[]"
                    AutofillSecureStore.saveCredentials(activity, json)
                    result.success(true)
                }

                "clearAutofillStore" -> {
                    AutofillSecureStore.clearCredentials(activity)
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

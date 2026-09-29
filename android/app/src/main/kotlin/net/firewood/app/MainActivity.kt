package net.firewood.app

import android.os.Bundle
import android.view.WindowManager
import net.firewood.app.security.AntiLeakActivityManager
import net.firewood.app.security.SecureMethodChannel
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private var secureMethodChannel: SecureMethodChannel? = null
    private var lifecycleChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Critical: Apply FLAG_SECURE BEFORE super.onCreate() calls setContentView()
        // This prevents the initial frame from appearing in app switcher thumbnails
        AntiLeakActivityManager.applyAllSecurityFlags(this)

        super.onCreate(savedInstanceState)

        // Defense-in-depth: apply again after Flutter sets up its views
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register the security method channel bridge
        // This is the single entry point for all Flutter ↔ Native security operations:
        //  - Biometric Keystore key wrapping (replaces raw password in FlutterSecureStorage)
        //  - Rate-limited unlock attempt tracking
        //  - Environment integrity checks
        //  - Screen capture flag control
        //  - Secure clipboard operations
        secureMethodChannel = SecureMethodChannel(this, flutterEngine)
        secureMethodChannel?.register()

        // MIUI recents-tray lock bridge. On this ROM the recents overview
        // hands top-resumed state to the launcher WITHOUT ever pausing or
        // stopping our activity (verified via `logcat -b events`: only
        // wm_on_top_resumed_lost + focus loss arrive, the activity stays
        // RESUMED/visible). Flutter therefore only receives `inactive`,
        // which must never lock (the biometric prompt looks identical).
        // `onTopResumedActivityChanged` is the discriminator: it fires for
        // recents/home/app-switch/other activities, but system windows
        // (BiometricPrompt) are not activities and never change it.
        lifecycleChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "net.firewood.app/lifecycle"
        )
    }

    override fun onTopResumedActivityChanged(isTopResumedActivity: Boolean) {
        super.onTopResumedActivityChanged(isTopResumedActivity)
        try {
            lifecycleChannel?.invokeMethod("topResumedActivity", isTopResumedActivity)
        } catch (_: Exception) {
            // Engine gone mid-callback — nothing to notify, lock already
            // covered by onPause/onStop when those fire.
        }
    }

    override fun onPause() {
        super.onPause()
        // Re-apply FLAG_SECURE when app is backgrounded
        // Prevents app switcher thumbnail leaks on buggy OEMs
        AntiLeakActivityManager.onAppBackgrounded(this)
    }

    override fun onResume() {
        super.onResume()
        // Ensure FLAG_SECURE is active after resume
        AntiLeakActivityManager.reapplySecureFlags(this)
    }

    override fun onDestroy() {
        secureMethodChannel?.detach()
        secureMethodChannel = null
        lifecycleChannel = null
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        secureMethodChannel?.onRequestPermissionsResult(requestCode, grantResults)
    }
}

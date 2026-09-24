package net.firewood.app

import android.os.Bundle
import android.view.WindowManager
import net.firewood.app.security.AntiLeakActivityManager
import net.firewood.app.security.SecureMethodChannel
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {

    private var secureMethodChannel: SecureMethodChannel? = null

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
        secureMethodChannel = null
        super.onDestroy()
    }
}

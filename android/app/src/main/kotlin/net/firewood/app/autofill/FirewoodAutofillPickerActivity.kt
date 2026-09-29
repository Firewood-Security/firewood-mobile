package net.firewood.app.autofill

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Build
import android.os.Bundle
import android.service.autofill.Dataset
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.autofill.AutofillId
import android.view.autofill.AutofillManager
import android.view.autofill.AutofillValue
import android.widget.TextView
import android.widget.Toast
import androidx.annotation.RequiresApi
import androidx.appcompat.app.AppCompatActivity
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import net.firewood.app.R
import net.firewood.app.security.AntiLeakActivityManager
import android.widget.RemoteViews

/**
 * FirewoodAutofillPickerActivity
 *
 * Launched by the Autofill Framework when the user taps the "🔒 Open Firewood" suggestion.
 * Flow:
 *   1. Biometric / master-password authentication
 *   2. Show a filtered list of matching credentials
 *   3. User selects one → build Dataset → setResult → Android fills the form
 *
 * Zero credentials are ever exposed in the system autofill dropdown.
 */
@RequiresApi(Build.VERSION_CODES.O)
class FirewoodAutofillPickerActivity : AppCompatActivity() {

    companion object {
        const val EXTRA_USERNAME_ID = "extra_username_id"
        const val EXTRA_PASSWORD_ID = "extra_password_id"
        const val EXTRA_WEB_DOMAIN  = "extra_web_domain"
        const val EXTRA_PACKAGE_NAME = "extra_package_name"
        const val EXTRA_IS_ANDROID_APP = "extra_is_android_app"

        fun buildPendingIntent(
            context: Context,
            usernameId: AutofillId?,
            passwordId: AutofillId?,
            webDomain: String?,
            packageName: String?,
            isAndroidApp: Boolean,
        ): PendingIntent {
            val intent = Intent(context, FirewoodAutofillPickerActivity::class.java).apply {
                // Fresh instance per fill: CLEAR_TASK only affects our own empty
                // task (taskAffinity=""), never the target app's task. NO_HISTORY
                // is intentionally avoided — it would destroy this activity while
                // the system biometric dialog is in front of it.
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TASK
                putExtra(EXTRA_USERNAME_ID, usernameId)
                putExtra(EXTRA_PASSWORD_ID, passwordId)
                putExtra(EXTRA_WEB_DOMAIN,  webDomain)
                putExtra(EXTRA_PACKAGE_NAME, packageName)
                putExtra(EXTRA_IS_ANDROID_APP, isAndroidApp)
            }
            return PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
            )
        }
    }

    private var usernameId: AutofillId? = null
    private var passwordId: AutofillId? = null
    private var webDomain: String? = null
    private var targetPackage: String? = null
    private var isAndroidApp: Boolean = false

    /** True while the system biometric dialog is in front of this activity. */
    private var authPromptVisible = false
    /** True once the credential list is on screen (i.e. we are "unlocked"). */
    private var listShown = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Screenshot / screen-recording / recents-thumbnail protection — this
        // screen renders real credentials.
        AntiLeakActivityManager.applyAllSecurityFlags(this)

        // Transparent window so the picker appears over the target app
        window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        setContentView(R.layout.activity_autofill_picker)

        // Tap outside the card, or on ✕, cancels the fill
        findViewById<View>(R.id.autofill_picker_scrim).setOnClickListener { cancelAndFinish() }
        findViewById<View>(R.id.autofill_picker_close).setOnClickListener { cancelAndFinish() }

        usernameId   = intent.getParcelableExtra(EXTRA_USERNAME_ID)
        passwordId   = intent.getParcelableExtra(EXTRA_PASSWORD_ID)
        webDomain    = intent.getStringExtra(EXTRA_WEB_DOMAIN)
        targetPackage = intent.getStringExtra(EXTRA_PACKAGE_NAME)
        isAndroidApp = intent.getBooleanExtra(EXTRA_IS_ANDROID_APP, false)

        authenticateAndShow()
    }

    override fun onStop() {
        super.onStop()
        // Re-lock: if the user leaves while credentials are visible (and no
        // system biometric dialog is the reason we stopped), drop the list.
        if (listShown && !authPromptVisible) {
            finish()
        }
    }

    // ─── Authentication ───────────────────────────────────────────────────────

    private fun authenticateAndShow() {
        val biometricManager = BiometricManager.from(this)
        val canAuthenticate = biometricManager.canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_STRONG or
            BiometricManager.Authenticators.DEVICE_CREDENTIAL
        )

        if (canAuthenticate == BiometricManager.BIOMETRIC_SUCCESS) {
            showBiometricPrompt()
        } else {
            // V-006: fail closed. Without an enrolled biometric *or* device
            // credential there is nothing on-device to verify the user with,
            // and the master password lives only inside the Flutter engine —
            // so the credential list must never be shown.
            Toast.makeText(
                this,
                "Set up a screen lock or fingerprint to use autofill",
                Toast.LENGTH_LONG
            ).show()
            cancelAndFinish()
        }
    }

    private fun showBiometricPrompt() {
        val executor = ContextCompat.getMainExecutor(this)
        val prompt = BiometricPrompt(
            this,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    authPromptVisible = false
                    showCredentialList()
                }
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    authPromptVisible = false
                    if (errorCode != BiometricPrompt.ERROR_USER_CANCELED &&
                        errorCode != BiometricPrompt.ERROR_NEGATIVE_BUTTON) {
                        Toast.makeText(
                            this@FirewoodAutofillPickerActivity,
                            "Authentication failed: $errString",
                            Toast.LENGTH_SHORT
                        ).show()
                    }
                    cancelAndFinish()
                }
                override fun onAuthenticationFailed() {
                    // system handles retry — the prompt is still in front
                }
            }
        )

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Firewood Vault")
            .setSubtitle("Authenticate to fill this form")
            .setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_STRONG or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
            )
            .build()

        authPromptVisible = true
        prompt.authenticate(promptInfo)
    }

    // ─── Credential List ──────────────────────────────────────────────────────

    private fun showCredentialList() {
        authPromptVisible = false
        val allCredentials = AutofillSecureStore.getCredentials(applicationContext)

        // V-006: strict context matching only — and NEVER fall back to
        // "show some vault entries anyway": zero matches means zero shown.
        val matched = filterCredentials(allCredentials)
        val toShow = matched.take(12)

        if (toShow.isEmpty()) {
            Toast.makeText(this, "No credentials match this site/app", Toast.LENGTH_LONG).show()
            cancelAndFinish()
            return
        }

        // Update the "searching for" label
        val contextLabel = when {
            !webDomain.isNullOrBlank() -> webDomain
            !targetPackage.isNullOrBlank() -> targetPackage!!.split(".").last()
            else -> "this form"
        }
        findViewById<TextView>(R.id.autofill_picker_context)?.text =
            "Matching $contextLabel"

        // Wire up RecyclerView
        val recycler = findViewById<RecyclerView>(R.id.autofill_picker_list)
        recycler.layoutManager = LinearLayoutManager(this)
        recycler.adapter = CredentialAdapter(toShow) { selected ->
            fillAndFinish(selected)
        }
        listShown = true
    }

    /**
     * V-006: strict context matching only.
     *
     *  * Native app fill: the entry's URL must be **exactly** the app URI
     *    `androidapp://<package>` (package equality) — no substring guessing.
     *  * Web fill: the entry's URL host must be the exact host or share the
     *    registrable domain (approx. eTLD+1) with the requested domain.
     *    `bank.com` never matches `mybank.com` or `bank.com.evil.tld`.
     *  * Title is never consulted; no match ⇒ empty list (caller cancels).
     */
    private fun filterCredentials(list: List<AutofillEntry>): List<AutofillEntry> {
        val pkg = targetPackage?.trim()
        if (!pkg.isNullOrEmpty()) {
            val appUri = "androidapp://$pkg"
            val byApp = list.filter {
                it.url.trim().equals(appUri, ignoreCase = true)
            }
            if (byApp.isNotEmpty()) return byApp
        }

        val domain = webDomain?.lowercase()?.trim()?.removePrefix("www.")
        if (domain.isNullOrEmpty()) return emptyList()

        return list.filter { item ->
            val host = extractHost(item.url.lowercase())
            host.isNotEmpty() && (host == domain || registrable(host) == registrable(domain))
        }
    }

    /** Approximate registrable domain (eTLD+1), mirroring the desktop bridge. */
    private fun registrable(host: String): String {
        val labels = host.split('.').filter { it.isNotEmpty() }
        if (labels.size <= 2) return host
        if (labels.all { it.toIntOrNull() != null }) return host // IPv4 literal
        val last = labels.last()
        val secondLevel = setOf("co", "com", "org", "net", "gov", "ac", "edu", "mil", "nom", "web")
        return if (last.length == 2 && labels[labels.size - 2] in secondLevel) {
            labels.takeLast(3).joinToString(".")
        } else {
            labels.takeLast(2).joinToString(".")
        }
    }

    private fun extractHost(urlStr: String): String {
        return try {
            val uri = java.net.URI(if (!urlStr.contains("://")) "https://$urlStr" else urlStr)
            (uri.host ?: "").removePrefix("www.")
        } catch (_: Exception) {
            urlStr.removePrefix("https://").removePrefix("http://")
                .split("/").firstOrNull()?.removePrefix("www.") ?: ""
        }
    }

    // ─── Fill & finish ────────────────────────────────────────────────────────

    private fun fillAndFinish(cred: AutofillEntry) {
        try {
            val presPackage = applicationContext.packageName
            val presentation = RemoteViews(presPackage, R.layout.autofill_dataset_item).apply {
                setTextViewText(R.id.autofill_item_title, cred.title.ifEmpty { "Firewood Credential" })
                setTextViewText(R.id.autofill_item_subtitle, cred.username.ifEmpty { "••••••••" })
            }

            val datasetBuilder = Dataset.Builder(presentation)
            var hasField = false
            if (usernameId != null && cred.username.isNotEmpty()) {
                datasetBuilder.setValue(usernameId!!, AutofillValue.forText(cred.username))
                hasField = true
            }
            if (passwordId != null && cred.password.isNotEmpty()) {
                datasetBuilder.setValue(passwordId!!, AutofillValue.forText(cred.password))
                hasField = true
            }
            if (!hasField) {
                val fallbackId = usernameId ?: passwordId
                if (fallbackId != null) {
                    datasetBuilder.setValue(
                        fallbackId,
                        AutofillValue.forText(cred.password.ifEmpty { cred.username.ifEmpty { " " } })
                    )
                }
            }

            val replyIntent = Intent().apply {
                putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, datasetBuilder.build())
            }
            setResult(Activity.RESULT_OK, replyIntent)
            finish()
        } catch (e: Throwable) {
            android.util.Log.e("FirewoodPicker", "Failed to fill and finish", e)
            cancelAndFinish()
        }
    }

    private fun cancelAndFinish() {
        setResult(Activity.RESULT_CANCELED)
        finish()
    }

    // ─── Adapter ─────────────────────────────────────────────────────────────

    private inner class CredentialAdapter(
        private val items: List<AutofillEntry>,
        private val onSelect: (AutofillEntry) -> Unit,
    ) : RecyclerView.Adapter<CredentialAdapter.VH>() {

        inner class VH(view: View) : RecyclerView.ViewHolder(view) {
            val title: TextView    = view.findViewById(R.id.autofill_item_title)
            val subtitle: TextView = view.findViewById(R.id.autofill_item_subtitle)
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
            val v = LayoutInflater.from(parent.context)
                .inflate(R.layout.autofill_picker_item, parent, false)
            return VH(v)
        }

        override fun onBindViewHolder(holder: VH, position: Int) {
            val item = items[position]
            holder.title.text    = item.title.ifEmpty { "Credential ${position + 1}" }
            holder.subtitle.text = item.username.ifEmpty { "No username" }
            holder.itemView.setOnClickListener { onSelect(item) }
        }

        override fun getItemCount() = items.size
    }
}

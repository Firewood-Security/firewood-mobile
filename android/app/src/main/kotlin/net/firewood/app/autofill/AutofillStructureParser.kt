package net.firewood.app.autofill

import android.app.assist.AssistStructure
import android.os.Build
import android.text.InputType
import android.view.View
import android.view.autofill.AutofillId
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.O)
class AutofillStructureParser(private val structure: AssistStructure) {
    var webDomain: String? = null
        private set
    var packageName: String? = null
        private set
    var usernameAutofillId: AutofillId? = null
        private set
    var passwordAutofillId: AutofillId? = null
        private set
    /** True when the fill target is an android:// app (not a browser web form) */
    var isAndroidApp: Boolean = false
        private set

    fun parse() {
        packageName = structure.activityComponent?.packageName
        val windowCount = structure.windowNodeCount

        // Pass 1: discover the web domain first, so isAndroidApp is already
        // correct when field matching runs (it gates the broad username fallback).
        for (i in 0 until windowCount) {
            findWebDomain(structure.getWindowNodeAt(i).rootViewNode)
            if (webDomain != null) break
        }
        isAndroidApp = webDomain.isNullOrBlank() && !packageName.isNullOrBlank()

        // Pass 2: identify username/password fields
        for (i in 0 until windowCount) {
            traverseViewNode(structure.getWindowNodeAt(i).rootViewNode)
        }
    }

    private fun findWebDomain(node: AssistStructure.ViewNode?) {
        if (node == null || webDomain != null) return
        if (!node.webDomain.isNullOrBlank()) {
            webDomain = node.webDomain
            return
        }
        val childCount = node.childCount
        for (i in 0 until childCount) {
            findWebDomain(node.getChildAt(i))
        }
    }

    private fun traverseViewNode(node: AssistStructure.ViewNode?) {
        if (node == null) return

        // 1. Extract web domain from browser or webview
        if (webDomain == null && !node.webDomain.isNullOrBlank()) {
            webDomain = node.webDomain
        }

        // 2. Identify fields
        val autofillHints = node.autofillHints
        val hintText = (node.hint ?: "").toString().lowercase()
        val idEntry = (node.idEntry ?: "").lowercase()
        val contentDesc = (node.contentDescription ?: "").toString().lowercase()
        val inputType = node.inputType

        val isTextClass = (inputType and InputType.TYPE_MASK_CLASS) == InputType.TYPE_CLASS_TEXT

        val isPasswordType = isTextClass &&
                ((inputType and InputType.TYPE_MASK_VARIATION) == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
                 (inputType and InputType.TYPE_MASK_VARIATION) == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD ||
                 (inputType and InputType.TYPE_MASK_VARIATION) == InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD)

        val hasPasswordHint = autofillHints?.any {
            it.equals(View.AUTOFILL_HINT_PASSWORD, ignoreCase = true)
        } == true ||
                hintText.containsAny("password", "passcode", "pin", "secret", "passwd") ||
                idEntry.containsAny("password", "passwd", "pwd", "pass", "secret", "pin")

        val hasUsernameHint = autofillHints?.any {
            it.equals(View.AUTOFILL_HINT_USERNAME, ignoreCase = true) ||
            it.equals(View.AUTOFILL_HINT_EMAIL_ADDRESS, ignoreCase = true) ||
            it.equals(View.AUTOFILL_HINT_PHONE, ignoreCase = true)
        } == true ||
                hintText.containsAny("username", "user name", "email", "e-mail", "login", "account", "phone", "mobile") ||
                idEntry.containsAny("user", "email", "login", "account", "uname", "userid") ||
                contentDesc.containsAny("username", "email", "login")

        val isEmailType = (inputType and InputType.TYPE_MASK_VARIATION) == InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS ||
                          (inputType and InputType.TYPE_MASK_VARIATION) == InputType.TYPE_TEXT_VARIATION_WEB_EMAIL_ADDRESS

        // For android:// apps: also accept unfocused text fields as potential username if we haven't found one
        val looksLikeUsernameField = isTextClass && !isPasswordType &&
                (hasUsernameHint || isEmailType ||
                 // Broad fallback for android apps: plain text input near a password field
                 (isAndroidApp && usernameAutofillId == null && node.autofillId != null))

        if (passwordAutofillId == null && (isPasswordType || hasPasswordHint)) {
            passwordAutofillId = node.autofillId
        } else if (usernameAutofillId == null && (looksLikeUsernameField || hasUsernameHint || isEmailType)) {
            usernameAutofillId = node.autofillId
        }

        // Recurse children
        val childCount = node.childCount
        for (i in 0 until childCount) {
            traverseViewNode(node.getChildAt(i))
        }
    }

    private fun String.containsAny(vararg keywords: String): Boolean =
        keywords.any { this.contains(it) }
}

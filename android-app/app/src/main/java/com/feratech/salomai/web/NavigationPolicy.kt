package com.feratech.salomai.web

import android.net.Uri
import androidx.core.net.toUri
import com.feratech.salomai.BuildConfig

/**
 * Decides what happens to every URL the WebView is asked to load.
 *
 * The rules exist for concrete reasons, not tidiness:
 *
 *  - Google **blocks its OAuth pages inside embedded WebViews**
 *    (`disallowed_useragent`). Any navigation to accounts.google.com is therefore
 *    intercepted and replaced with native Google Sign-In.
 *  - Apple, in contrast, does *not* block WebViews, so the existing web Apple flow
 *    is left alone and stays in-app.
 *  - Click/Payme checkout (and their 3-D Secure hops) must stay in the WebView.
 *    Sending them to a browser would break the `return_url` round trip back to
 *    salom-ai.uz/payment/result, which the web app polls for on resume.
 *  - Telegram links must leave the app so the Telegram client handles them —
 *    that is the whole point of the phone → bot → code login.
 */
object NavigationPolicy {

    sealed interface Decision {
        /** Load it in our WebView. */
        data object Internal : Decision

        /** Cancel the load and run native Google Sign-In instead. */
        data object NativeGoogleSignIn : Decision

        /** Hand off to another installed app (Telegram, dialer, mail, Play Store). */
        data class OpenExternalApp(val uri: Uri) : Decision

        /** Not ours and not an app link — show it in a Custom Tab. */
        data class OpenCustomTab(val uri: Uri) : Decision
    }

    private val webHost: String = Uri.parse(BuildConfig.WEB_ORIGIN).host ?: "salom-ai.uz"

    /** Our own surfaces. */
    private val internalHosts = setOf(webHost, "www.$webHost", "api.$webHost")

    /**
     * Third-party hosts that must render *inside* the app because they are part of
     * a flow that has to return to us: payment checkout and Apple sign-in.
     */
    private val inAppThirdPartyHosts = setOf(
        "appleid.apple.com",
        "click.uz", "my.click.uz", "api.click.uz",
        "payme.uz", "checkout.paycom.uz", "paycom.uz",
    )

    /** Hosts whose pages Google refuses to serve inside a WebView. */
    private val googleAuthHosts = setOf("accounts.google.com", "accounts.youtube.com")

    /** Schemes that always belong to another app. */
    private val externalAppSchemes = setOf("tg", "mailto", "tel", "sms", "smsto", "market", "intent")

    fun decide(url: String): Decision {
        val uri = runCatching { url.toUri() }.getOrNull() ?: return Internal
        val scheme = uri.scheme?.lowercase()
        val host = uri.host?.lowercase().orEmpty()

        if (scheme != null && scheme in externalAppSchemes) return Decision.OpenExternalApp(uri)
        if (scheme != "http" && scheme != "https") return Decision.OpenExternalApp(uri)

        if (host in googleAuthHosts) return Decision.NativeGoogleSignIn

        // Telegram deep links: hand to the Telegram app (falls back to a Custom Tab
        // if Telegram is not installed — handled by the caller).
        if (host == "t.me" || host == "telegram.me" || host.endsWith(".t.me")) {
            return Decision.OpenExternalApp(uri)
        }

        if (host in internalHosts || host.endsWith(".$webHost")) return Decision.Internal
        if (host in inAppThirdPartyHosts || inAppThirdPartyHosts.any { host.endsWith(".$it") }) {
            return Decision.Internal
        }

        return Decision.OpenCustomTab(uri)
    }

    private val Internal = Decision.Internal

    /** True when the URL belongs to us — used to gate the JS bridge. */
    fun isOwnOrigin(url: String?): Boolean {
        val host = runCatching { Uri.parse(url ?: return false).host }.getOrNull()?.lowercase()
            ?: return false
        return host == webHost || host == "www.$webHost"
    }
}

package com.feratech.salomai.web

import android.graphics.Bitmap
import android.net.Uri
import android.net.http.SslError
import android.webkit.SslErrorHandler
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient

/**
 * Navigation and error policy for the shell's single WebView.
 */
class SalomWebViewClient(
    private val onGoogleSignInRequested: () -> Unit,
    private val onOpenExternalApp: (Uri) -> Unit,
    private val onOpenCustomTab: (Uri) -> Unit,
    private val onPageStarted: (url: String) -> Unit,
    private val onPageReady: (view: WebView, url: String) -> Unit,
    private val onFirstPaint: () -> Unit,
    private val onMainFrameError: (kind: ErrorKind) -> Unit,
    private val onRendererGone: () -> Unit,
) : WebViewClient() {

    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
        val url = request.url.toString()
        return when (val decision = NavigationPolicy.decide(url)) {
            is NavigationPolicy.Decision.Internal -> false // let the WebView load it

            is NavigationPolicy.Decision.NativeGoogleSignIn -> {
                onGoogleSignInRequested()
                true
            }

            is NavigationPolicy.Decision.OpenExternalApp -> {
                onOpenExternalApp(decision.uri)
                true
            }

            is NavigationPolicy.Decision.OpenCustomTab -> {
                // Only hand off real user navigations. A redirect chain inside a
                // flow we own should stay put.
                if (request.isForMainFrame && request.hasGesture()) {
                    onOpenCustomTab(decision.uri)
                    true
                } else {
                    false
                }
            }
        }
    }

    override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
        super.onPageStarted(view, url, favicon)
        onPageStarted(url)
    }

    override fun onPageFinished(view: WebView, url: String) {
        super.onPageFinished(view, url)
        onPageReady(view, url)
    }

    /**
     * A bad certificate is never something to click through — proceeding would
     * hand the user's session to whoever presented it. Cancel and surface it as a
     * connection problem (captive-portal Wi-Fi is the usual cause in practice).
     */
    override fun onReceivedSslError(view: WebView, handler: SslErrorHandler, error: SslError) {
        handler.cancel()
        onMainFrameError(ErrorKind.SERVER)
    }

    /**
     * How much we actually know about a failed load.
     *
     * The WebView error code deliberately does NOT decide the message: ERROR_CONNECT,
     * ERROR_HOST_LOOKUP and ERROR_TIMEOUT all occur both when the phone is offline
     * and when the phone is fine but the server is not. Only ConnectivityManager can
     * tell those apart, so [UNKNOWN] defers to the caller. [SERVER] is reserved for
     * failures that are unambiguously not the user's network — a 5xx response or a
     * bad certificate, both of which required a working connection to observe.
     */
    enum class ErrorKind { UNKNOWN, SERVER }

    /** First frame of real content — the moment it is safe to drop the splash. */
    override fun onPageCommitVisible(view: WebView, url: String) {
        super.onPageCommitVisible(view, url)
        onFirstPaint()
    }

    /**
     * The renderer process was killed (usually low memory while backgrounded).
     * Without handling this the whole app is torn down by the system.
     */
    override fun onRenderProcessGone(
        view: WebView,
        detail: android.webkit.RenderProcessGoneDetail,
    ): Boolean {
        onRendererGone()
        return true
    }

    override fun onReceivedError(
        view: WebView,
        request: WebResourceRequest,
        error: WebResourceError,
    ) {
        super.onReceivedError(view, request, error)
        // Sub-resource failures (an ad script, one image) must never blank the app.
        if (!request.isForMainFrame) return
        onMainFrameError(ErrorKind.UNKNOWN)
    }

    override fun onReceivedHttpError(
        view: WebView,
        request: WebResourceRequest,
        errorResponse: WebResourceResponse,
    ) {
        super.onReceivedHttpError(view, request, errorResponse)
        if (!request.isForMainFrame) return
        // 4xx/5xx on the document itself: the site is up but the page is not
        // usable. 404s are handled by the SPA, so only surface server failures.
        if (errorResponse.statusCode >= 500) {
            onMainFrameError(ErrorKind.SERVER)
        }
    }
}

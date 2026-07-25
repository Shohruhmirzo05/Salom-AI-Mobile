package com.feratech.salomai.web

import android.net.Uri
import android.os.Message
import android.view.ViewGroup
import android.webkit.PermissionRequest
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient

/**
 * Bridges the browser-level capabilities the web app relies on to their native
 * Android equivalents: the file picker, microphone/camera permission, and
 * `window.open`.
 */
class SalomWebChromeClient(
    private val onProgress: (Int) -> Unit,
    private val onFileChooser: (ValueCallback<Array<Uri>>, FileChooserParams) -> Boolean,
    private val onMediaPermission: (PermissionRequest) -> Unit,
    private val onOpenUrlInNewWindow: (Uri) -> Unit,
) : WebChromeClient() {

    override fun onProgressChanged(view: WebView, newProgress: Int) {
        onProgress(newProgress)
    }

    override fun onShowFileChooser(
        webView: WebView,
        filePathCallback: ValueCallback<Array<Uri>>,
        fileChooserParams: FileChooserParams,
    ): Boolean = onFileChooser(filePathCallback, fileChooserParams)

    /**
     * Microphone for realtime voice (`getUserMedia` in web/src/lib/realtime-voice.ts)
     * and camera for image capture. The Android runtime permission is requested
     * first; only then is the web permission granted.
     */
    override fun onPermissionRequest(request: PermissionRequest) {
        onMediaPermission(request)
    }

    /**
     * `window.open(..., '_blank')` — used by the Telegram login flow and the
     * Click/Payme checkout hand-off.
     *
     * The WebView gives us a callback, not a URL, so the standard trick is a
     * throwaway WebView whose only job is to report the first navigation. That URL
     * then goes through [NavigationPolicy] like any other.
     */
    override fun onCreateWindow(
        view: WebView,
        isDialog: Boolean,
        isUserGesture: Boolean,
        resultMsg: Message,
    ): Boolean {
        val probe = WebView(view.context)
        probe.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(
                probeView: WebView,
                request: android.webkit.WebResourceRequest,
            ): Boolean {
                onOpenUrlInNewWindow(request.url)
                destroy(probe)
                return true
            }
        }
        (resultMsg.obj as? WebView.WebViewTransport)?.webView = probe
        resultMsg.sendToTarget()
        return true
    }

    private fun destroy(probe: WebView) {
        probe.post {
            (probe.parent as? ViewGroup)?.removeView(probe)
            probe.destroy()
        }
    }
}

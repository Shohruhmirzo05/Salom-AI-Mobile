package com.feratech.salomai.web

import android.app.Activity
import android.app.DownloadManager
import androidx.core.net.toUri
import android.os.Environment
import android.webkit.CookieManager
import android.webkit.DownloadListener
import android.webkit.MimeTypeMap
import android.webkit.URLUtil
import android.widget.Toast
import com.feratech.salomai.R

/**
 * Routes web downloads through Android's DownloadManager.
 *
 * This is one of the places a wrapper stops feeling like a browser: the generated
 * .pptx / .docx lands in the system Downloads folder with a progress notification
 * attributed to Salom AI, and opens with a tap — instead of disappearing into
 * Chrome's download list.
 *
 * Two entry points, because one is not enough:
 *
 *  - [onDownloadStart] fires when the WebView itself decides a navigation is a
 *    download, i.e. for content types it cannot render (.pptx, .docx).
 *  - [start] is called from the injected `a[download]` click handler. WebView
 *    **ignores the HTML5 `download` attribute** for anything it *can* render, so
 *    without this a generated image would open in place of downloading — a
 *    regression against the same page in Chrome.
 */
class DownloadHandler(private val activity: Activity) : DownloadListener {

    override fun onDownloadStart(
        url: String,
        userAgent: String?,
        contentDisposition: String?,
        mimeType: String?,
        contentLength: Long,
    ) {
        start(url, URLUtil.guessFileName(url, contentDisposition, mimeType), mimeType, userAgent)
    }

    fun start(url: String, suggestedName: String?, mimeType: String? = null, userAgent: String? = null) {
        // blob:/data: URLs cannot be handed to DownloadManager. The web app builds
        // its download links from real https URLs (api.salom-ai.uz/uploads/...),
        // so this is a guard rather than an expected path.
        if (!url.startsWith("http://") && !url.startsWith("https://")) {
            toast(R.string.download_failed)
            return
        }

        val fileName = suggestedName?.takeIf { it.isNotBlank() }
            ?: URLUtil.guessFileName(url, null, mimeType)

        val request = DownloadManager.Request(url.toUri()).apply {
            setMimeType(mimeType ?: mimeTypeFor(fileName))
            // Carry the session across: /uploads/ may be behind an auth cookie.
            CookieManager.getInstance().getCookie(url)?.let { addRequestHeader("Cookie", it) }
            userAgent?.let { addRequestHeader("User-Agent", it) }
            setTitle(fileName)
            setDescription(activity.getString(R.string.download_in_progress))
            setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName)
            setAllowedOverMetered(true)
            setAllowedOverRoaming(true)
        }

        val manager = activity.getSystemService(DownloadManager::class.java)
        if (manager == null) {
            toast(R.string.download_failed)
            return
        }

        runCatching { manager.enqueue(request) }
            .onSuccess { toast(R.string.download_started) }
            .onFailure { toast(R.string.download_failed) }
    }

    private fun mimeTypeFor(fileName: String): String {
        val ext = MimeTypeMap.getFileExtensionFromUrl(fileName)
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: "*/*"
    }

    private fun toast(resId: Int) {
        activity.runOnUiThread { Toast.makeText(activity, resId, Toast.LENGTH_SHORT).show() }
    }
}

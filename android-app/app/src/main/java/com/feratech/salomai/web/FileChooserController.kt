package com.feratech.salomai.web

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.result.registerForActivityResult
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.FileProvider
import com.feratech.salomai.R
import java.io.File

/**
 * Serves `<input type="file">` — avatar upload (web/src/pages/Settings.tsx) and
 * chat/image attachments (web/src/pages/Images.tsx).
 *
 * Offers the gallery/document picker *and* a direct camera capture, because
 * "take a photo of this homework" is a primary use case and burying it two taps
 * deep inside the document picker is the sort of thing that makes a wrapper feel
 * like a website.
 */
class FileChooserController(private val activity: AppCompatActivity) {

    private var pendingCallback: ValueCallback<Array<Uri>>? = null
    private var cameraOutputUri: Uri? = null

    private val launcher: ActivityResultLauncher<Intent> =
        activity.registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            deliver(result.resultCode, result.data)
        }

    /** @return true when the chooser was shown; false makes the WebView give up cleanly. */
    fun show(
        callback: ValueCallback<Array<Uri>>,
        params: WebChromeClient.FileChooserParams,
    ): Boolean {
        // A second request while one is open would strand the first callback and
        // freeze the file input forever.
        pendingCallback?.onReceiveValue(null)
        pendingCallback = callback
        cameraOutputUri = null

        val content = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = params.acceptTypes.firstOrNull { it.isNotBlank() } ?: "*/*"
            if (params.acceptTypes.size > 1) {
                putExtra(Intent.EXTRA_MIME_TYPES, params.acceptTypes.filter { it.isNotBlank() }.toTypedArray())
            }
            putExtra(
                Intent.EXTRA_ALLOW_MULTIPLE,
                params.mode == WebChromeClient.FileChooserParams.MODE_OPEN_MULTIPLE,
            )
        }

        val chooser = Intent.createChooser(content, activity.getString(R.string.file_chooser_title))
        cameraIntent(params)?.let { chooser.putExtra(Intent.EXTRA_INITIAL_INTENTS, arrayOf(it)) }

        return runCatching { launcher.launch(chooser); true }
            .getOrElse {
                pendingCallback = null
                false
            }
    }

    private fun cameraIntent(params: WebChromeClient.FileChooserParams): Intent? {
        val wantsImages = params.acceptTypes.isEmpty() ||
            params.acceptTypes.any { it.isBlank() || it.startsWith("image/") || it == "*/*" }
        if (!wantsImages) return null

        val capture = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
        if (capture.resolveActivity(activity.packageManager) == null) return null

        val dir = File(activity.cacheDir, "captures").apply { mkdirs() }
        val photo = runCatching { File.createTempFile("capture_", ".jpg", dir) }.getOrNull()
            ?: return null

        val uri = runCatching {
            FileProvider.getUriForFile(
                activity,
                activity.getString(R.string.providerAuthority),
                photo,
            )
        }.getOrNull() ?: return null

        cameraOutputUri = uri
        capture.putExtra(MediaStore.EXTRA_OUTPUT, uri)
        // Grant read+write explicitly via ClipData rather than relying on the
        // implicit EXTRA_OUTPUT grant: Android logs that the implicit grant "will
        // be discontinued from Android 18 onwards", which would silently break
        // photo capture on a future OS with no app change on our side.
        capture.clipData = ClipData.newRawUri(MediaStore.EXTRA_OUTPUT, uri)
        capture.addFlags(
            Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION
        )
        return capture
    }

    private fun deliver(resultCode: Int, data: Intent?) {
        val callback = pendingCallback ?: return
        pendingCallback = null

        if (resultCode != Activity.RESULT_OK) {
            callback.onReceiveValue(null)
            discardCapture()
            return
        }

        val uris = extractUris(data)
        callback.onReceiveValue(uris)
        if (uris == null || cameraOutputUri !in uris.orEmpty().toList()) discardCapture()
    }

    private fun extractUris(data: Intent?): Array<Uri>? {
        // Null data with RESULT_OK means the camera wrote to the URI we supplied.
        if (data == null || (data.data == null && data.clipData == null)) {
            return cameraOutputUri?.let { arrayOf(it) }
        }
        data.clipData?.let { clip ->
            return (0 until clip.itemCount).mapNotNull { clip.getItemAt(it).uri }.toTypedArray()
        }
        return data.data?.let { arrayOf(it) }
    }

    /** Removes the temp capture file when the user backed out of the camera. */
    private fun discardCapture() {
        val uri = cameraOutputUri ?: return
        cameraOutputUri = null
        runCatching { activity.contentResolver.delete(uri, null, null) }
    }

    /** Release a stranded callback if the activity goes away mid-chooser. */
    fun cancel() {
        pendingCallback?.onReceiveValue(null)
        pendingCallback = null
    }
}

package com.feratech.salomai

import android.Manifest
import android.annotation.SuppressLint
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.webkit.CookieManager
import android.webkit.JavascriptInterface
import android.webkit.PermissionRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.widget.Button
import android.widget.ProgressBar
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.graphics.ColorUtils
import androidx.core.graphics.toColorInt
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.lifecycleScope
import com.feratech.salomai.auth.GoogleSignInBridge
import com.feratech.salomai.auth.SessionWatcher
import com.feratech.salomai.net.SalomApi
import com.feratech.salomai.push.PushManager
import com.feratech.salomai.web.DownloadHandler
import com.feratech.salomai.web.FileChooserController
import com.feratech.salomai.web.NavigationPolicy
import com.feratech.salomai.web.SalomWebChromeClient
import com.feratech.salomai.web.SalomWebViewClient
import kotlinx.coroutines.launch

/**
 * The whole app: one WebView showing salom-ai.uz, plus the native plumbing that
 * makes it behave like an app rather than a page in a browser.
 */
class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private lateinit var progressBar: ProgressBar
    private lateinit var offlineView: View
    private lateinit var loadingView: View
    private lateinit var fileChooser: FileChooserController
    private lateinit var sessionWatcher: SessionWatcher
    private lateinit var downloads: DownloadHandler
    private lateinit var googleSignIn: GoogleSignInBridge

    private var firstPaintDone = false
    private var signingIn = false
    private var errorState = ErrorState.NONE
    private var loadWatchdogArmed = false
    private var watchdogTrippedError = false
    private var lastRendererDeathAt = 0L
    private val uiHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var pendingMediaRequest: PermissionRequest? = null
    private var pendingPushPrompt = false

    private val mediaPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { grants ->
            val request = pendingMediaRequest
            pendingMediaRequest = null
            if (request == null) return@registerForActivityResult
            if (grants.values.all { it }) request.grant(request.resources) else request.deny()
        }

    private val notificationPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { /* result handled by OneSignal */ }

    // ------------------------------------------------------------------ lifecycle

    override fun onCreate(savedInstanceState: Bundle?) {
        val splash = installSplashScreen()
        super.onCreate(savedInstanceState)
        // Hold the splash until the page actually paints, so there is never a
        // flash of empty white between the launcher icon and the app.
        splash.setKeepOnScreenCondition { !firstPaintDone }
        // Hard ceiling on the splash. Without this a hanging server or a captive
        // portal leaves the app sitting on the splash forever, which reads as a
        // frozen app rather than a slow one.
        uiHandler.postDelayed({ firstPaintDone = true }, SPLASH_MAX_MS)

        WindowCompat.setDecorFitsSystemWindows(window, false)
        // Android System WebView can be disabled or be mid-update, in which case
        // inflating a WebView throws. Crashing on launch is the worst possible
        // answer; tell the user what to do instead.
        try {
            setContentView(R.layout.activity_main)
        } catch (e: Exception) {
            showWebViewUnavailable()
            return
        }

        webView = findViewById(R.id.web_view)
        progressBar = findViewById(R.id.progress)
        offlineView = findViewById(R.id.offline_view)
        loadingView = findViewById(R.id.loading_view)

        fileChooser = FileChooserController(this)
        googleSignIn = GoogleSignInBridge(this)
        sessionWatcher = SessionWatcher(lifecycleScope) { promptForPushOnce() }

        applyWindowInsets()
        configureWebView()
        wireOfflineRetry()
        wireBackNavigation()

        if (savedInstanceState != null && webView.restoreState(savedInstanceState) != null) return
        loadInitialUrl(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Deep link, launcher shortcut or notification tap while already running.
        intent.data?.takeIf { NavigationPolicy.isOwnOrigin(it.toString()) }
            ?.let { webView.loadUrl(it.toString()) }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        webView.saveState(outState)
    }

    override fun onPause() {
        super.onPause()
        webView.onPause()
        // Persist cookies now: the process can be killed while backgrounded and an
        // unflushed session cookie means a surprise logout.
        CookieManager.getInstance().flush()
    }

    override fun onResume() {
        super.onResume()
        webView.onResume()
        // Coming back to a visible error screen with the network restored must
        // RELOAD, not merely hide the overlay — hiding it alone would reveal a
        // blank WebView that never got its page.
        if (errorState != ErrorState.NONE && !isOffline()) retryLoad()
        else if (isOffline() && !firstPaintDone) showError(ErrorState.NO_CONNECTION)
    }

    override fun onDestroy() {
        uiHandler.removeCallbacksAndMessages(null)
        fileChooser.cancel()
        webView.destroy()
        super.onDestroy()
    }

    // ------------------------------------------------------------------ WebView

    @SuppressLint("SetJavaScriptEnabled")
    private fun configureWebView() {
        WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG)

        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            // Realtime voice starts audio without a click on the <audio> element
            // itself, so the gesture requirement has to go.
            mediaPlaybackRequiresUserGesture = false
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            javaScriptCanOpenWindowsAutomatically = true
            setSupportMultipleWindows(true)
            useWideViewPort = true
            loadWithOverviewMode = false
            cacheMode = WebSettings.LOAD_DEFAULT
            // Keep the "; wv" token: identifying as a WebView is what Google's
            // OAuth check expects to see, and we honour it with native sign-in
            // rather than hiding from it.
            userAgentString = "$userAgentString SalomAI/${BuildConfig.VERSION_NAME}"
        }

        CookieManager.getInstance().apply {
            setAcceptCookie(true)
            setAcceptThirdPartyCookies(webView, true)
        }

        webView.setBackgroundColor(SURFACE_DEFAULT.toColorInt())
        webView.overScrollMode = View.OVER_SCROLL_NEVER
        webView.isVerticalScrollBarEnabled = false

        downloads = DownloadHandler(this)
        webView.setDownloadListener(downloads)
        webView.addJavascriptInterface(SurfaceBridge(), "SalomNative")

        webView.webViewClient = SalomWebViewClient(
            onGoogleSignInRequested = ::startGoogleSignIn,
            onOpenExternalApp = ::openExternalApp,
            onOpenCustomTab = ::openCustomTab,
            onPageStarted = {
                if (!isOffline()) hideError()
                armLoadWatchdog()
            },
            onPageReady = { view, url ->
                disarmLoadWatchdog()
                if (watchdogTrippedError) {
                    // The load did complete after all — take the error screen away
                    // rather than covering a working page with it.
                    watchdogTrippedError = false
                    hideError()
                }
                if (NavigationPolicy.isOwnOrigin(url)) {
                    sessionWatcher.syncFrom(view)
                    view.evaluateJavascript(SURFACE_BRIDGE_JS, null)
                } else if (isDebugHarness()) {
                    view.evaluateJavascript(SURFACE_BRIDGE_JS, null)
                }
            },
            // First paint means "the shell painted", not "the app is usable" — on a
            // slow link the HTML commits in a second while the JS bundle takes
            // another minute. It dismisses the splash and nothing more.
            onFirstPaint = {
                firstPaintDone = true
                loadingView.visibility = View.GONE
            },
            onMainFrameError = { kind ->
                disarmLoadWatchdog()
                // "No internet" is the wrong thing to say when the phone is online
                // and it is our server, TLS or DNS that failed — it sends the user
                // to toggle Wi-Fi for a problem Wi-Fi cannot fix.
                showError(
                    if (kind == SalomWebViewClient.ErrorKind.UNKNOWN && isOffline()) {
                        ErrorState.NO_CONNECTION
                    } else {
                        ErrorState.SERVER
                    }
                )
            },
            onRendererGone = {
                // A single renderer death is recoverable — rebuild the activity and
                // the user lands back where they were. Repeated deaths are not:
                // recreating in a loop would spin forever on a device that simply
                // cannot keep the renderer alive, so stop and offer a retry instead.
                val now = android.os.SystemClock.elapsedRealtime()
                if (now - lastRendererDeathAt < RENDERER_DEATH_WINDOW_MS) {
                    showError(ErrorState.SERVER)
                } else {
                    lastRendererDeathAt = now
                    Toast.makeText(this, R.string.reloading, Toast.LENGTH_SHORT).show()
                    recreate()
                }
            },
        )

        webView.webChromeClient = SalomWebChromeClient(
            onProgress = ::onLoadProgress,
            onFileChooser = { callback, params -> fileChooser.show(callback, params) },
            onMediaPermission = ::handleMediaPermission,
            onOpenUrlInNewWindow = ::routeNewWindow,
        )
    }

    private fun loadInitialUrl(intent: Intent?) {
        // Debug-only capability harness — exercises the file picker, downloads and
        // microphone bridges without needing an account:
        //   adb shell am start -n com.feratech.salomai/.MainActivity -e devtest 1
        if (BuildConfig.DEBUG && intent?.getStringExtra("devtest") != null) {
            firstPaintDone = true
            webView.loadUrl("file:///android_asset/devtest.html")
            return
        }

        val deepLink = intent?.data?.toString()?.takeIf { NavigationPolicy.isOwnOrigin(it) }
        if (isOffline()) {
            showError(ErrorState.NO_CONNECTION)
            firstPaintDone = true // never hold the splash on a dead network
            return
        }
        webView.loadUrl(deepLink ?: BuildConfig.START_URL)
    }

    private fun onLoadProgress(progress: Int) {
        progressBar.progress = progress
        progressBar.visibility = if (progress in 1..99) View.VISIBLE else View.GONE
    }

    // ------------------------------------------------------------------ navigation

    private fun routeNewWindow(uri: Uri) {
        when (val decision = NavigationPolicy.decide(uri.toString())) {
            is NavigationPolicy.Decision.Internal -> webView.loadUrl(uri.toString())
            is NavigationPolicy.Decision.NativeGoogleSignIn -> startGoogleSignIn()
            is NavigationPolicy.Decision.OpenExternalApp -> openExternalApp(decision.uri)
            is NavigationPolicy.Decision.OpenCustomTab -> openCustomTab(decision.uri)
        }
    }

    private fun openExternalApp(uri: Uri) {
        val intent = if (uri.scheme == "intent") {
            runCatching { Intent.parseUri(uri.toString(), Intent.URI_INTENT_SCHEME) }.getOrNull()
        } else {
            Intent(Intent.ACTION_VIEW, uri)
        } ?: return

        try {
            startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            // Telegram not installed, for example — fall back to the web version.
            if (uri.scheme == "http" || uri.scheme == "https") openCustomTab(uri)
            else Toast.makeText(this, R.string.no_app_to_open, Toast.LENGTH_SHORT).show()
        }
    }

    private fun openCustomTab(uri: Uri) {
        val intent = CustomTabsIntent.Builder()
            .setShowTitle(true)
            .setUrlBarHidingEnabled(true)
            .build()
        try {
            intent.launchUrl(this, uri)
        } catch (e: ActivityNotFoundException) {
            openExternalApp(uri)
        }
    }

    private fun wireBackNavigation() {
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                when {
                    offlineView.visibility == View.VISIBLE -> finish()
                    webView.canGoBack() -> webView.goBack()
                    else -> finish()
                }
            }
        })
    }

    // ------------------------------------------------------------------ sign-in

    /**
     * Runs when the web app tries to navigate to accounts.google.com. Google
     * rejects that page inside a WebView, so we do it natively and hand the
     * resulting session back to the web app.
     */
    private fun startGoogleSignIn() {
        if (signingIn) return
        signingIn = true
        progressBar.visibility = View.VISIBLE

        lifecycleScope.launch {
            try {
                when (val result = googleSignIn.signIn()) {
                    // The web button already switched to "Redirecting to Google…"
                    // before we cancelled the navigation, so its spinner is stuck
                    // on. Reloading the login page is the only way to reset that
                    // React state without touching the web codebase.
                    is GoogleSignInBridge.Result.Cancelled -> resetLoginScreen()

                    is GoogleSignInBridge.Result.Failure -> {
                        Toast.makeText(this@MainActivity, R.string.google_sign_in_failed, Toast.LENGTH_LONG).show()
                        resetLoginScreen()
                    }

                    is GoogleSignInBridge.Result.Success -> {
                        val session = SalomApi.verifyGoogleIdToken(result.idToken)
                        if (session == null) {
                            Toast.makeText(this@MainActivity, R.string.google_sign_in_failed, Toast.LENGTH_LONG).show()
                            resetLoginScreen()
                        } else {
                            sessionWatcher.inject(webView, session) {
                                webView.loadUrl("${BuildConfig.WEB_ORIGIN}/chat?source=android")
                            }
                        }
                    }
                }
            } finally {
                signingIn = false
                progressBar.visibility = View.GONE
            }
        }
    }

    /**
     * Puts the login screen back to a usable state after an abandoned native
     * sign-in. `reload()` rather than `goBack()`: the OAuth navigation was
     * cancelled, so there is no history entry to go back to.
     */
    private fun resetLoginScreen() {
        if (webView.url?.contains("/login") == true) webView.reload()
        else webView.loadUrl("${BuildConfig.WEB_ORIGIN}/login?source=android")
    }

    /** Asked once, only after sign-in — Android 13+ gives exactly one prompt. */
    private fun promptForPushOnce() {
        if (pendingPushPrompt || !PushManager.isConfigured) return
        pendingPushPrompt = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
        lifecycleScope.launch { PushManager.requestPermission() }
    }

    // ------------------------------------------------------------------ permissions

    /**
     * Turns a web permission prompt into the native one, so the dialog says
     * "Salom AI" rather than "salom-ai.uz".
     */
    private fun handleMediaPermission(request: PermissionRequest) {
        val fromHarness = BuildConfig.DEBUG && request.origin.toString().startsWith("file://")
        if (!NavigationPolicy.isOwnOrigin(request.origin.toString()) && !fromHarness) {
            request.deny()
            return
        }

        // Audio only. RESOURCE_VIDEO_CAPTURE would need the CAMERA permission,
        // which the manifest deliberately does not declare (see the comment
        // there) — the web app captures photos through the file picker, not
        // getUserMedia. Denying is the honest answer rather than requesting a
        // permission we cannot hold.
        val needed = request.resources.mapNotNull {
            when (it) {
                PermissionRequest.RESOURCE_AUDIO_CAPTURE -> Manifest.permission.RECORD_AUDIO
                else -> null
            }
        }.distinct()

        if (needed.isEmpty()) {
            request.deny()
            return
        }

        val missing = needed.filter {
            checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            request.grant(request.resources)
            return
        }

        pendingMediaRequest = request
        mediaPermissionLauncher.launch(missing.toTypedArray())
    }

    // ------------------------------------------------------------------ chrome

    /**
     * Pads the WebView out of the system bars and paints the bar areas with the
     * page's own background colour, so there is no seam.
     *
     * The site's viewport meta has no `viewport-fit=cover`, so `env(safe-area-*)`
     * resolves to 0 inside a WebView — insets have to be applied natively or the
     * bottom tab bar would sit under the gesture pill.
     */
    private fun applyWindowInsets() {
        val root = findViewById<View>(R.id.root)
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            val ime = insets.getInsets(WindowInsetsCompat.Type.ime())
            // Padding the *container*, not the WebView: WebView does not reliably
            // inset its rendered page from its own padding, so the page ended up
            // drawing under the status bar. Padding the parent lays the WebView
            // out inside the safe area instead, and the root's background paints
            // the bar strips.
            view.setPadding(bars.left, bars.top, bars.right, maxOf(bars.bottom, ime.bottom))
            WindowInsetsCompat.CONSUMED
        }
    }

    /** Receives the page's surface colour so the system bars match the web theme. */
    private inner class SurfaceBridge {

        /**
         * Backs the `navigator.share` polyfill with the real Android share sheet.
         *
         * Android WebView does not implement the Web Share API (verified: the
         * capability harness reports `navigator.share false`), so the share button
         * in web/src/pages/PresentationEditor.tsx would silently do nothing —
         * it is guarded by `if (navigator.share)`. Rather than lose the feature,
         * the shell supplies it natively, which is also a better result than
         * Chrome's own sheet.
         */
        @JavascriptInterface
        fun share(title: String?, text: String?, url: String?) {
            runOnUiThread {
                if (!NavigationPolicy.isOwnOrigin(webView.url) && !isDebugHarness()) return@runOnUiThread
                val payload = listOfNotNull(text?.takeIf { it.isNotBlank() }, url?.takeIf { it.isNotBlank() })
                    .joinToString("\n")
                if (payload.isBlank()) return@runOnUiThread
                val send = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, payload)
                    title?.takeIf { it.isNotBlank() }?.let { putExtra(Intent.EXTRA_SUBJECT, it) }
                }
                runCatching { startActivity(Intent.createChooser(send, title ?: getString(R.string.appName))) }
            }
        }

        /**
         * Backs the injected `a[download]` interceptor. WebView ignores the HTML5
         * `download` attribute for content types it can render, so a generated
         * image would open in place of downloading. Routing every download link
         * here keeps the behaviour identical for .pptx, .docx and images alike.
         */
        @JavascriptInterface
        fun download(url: String, filename: String?) {
            runOnUiThread {
                if (!NavigationPolicy.isOwnOrigin(webView.url) && !isDebugHarness()) return@runOnUiThread
                downloads.start(url, filename?.takeIf { it.isNotBlank() })
            }
        }

        @JavascriptInterface
        fun onSurfaceColor(css: String) {
            // The bridge is visible to any page the WebView loads (Click/Payme
            // checkout included), so only act on our own origin.
            runOnUiThread {
                if (!NavigationPolicy.isOwnOrigin(webView.url) && !isDebugHarness()) return@runOnUiThread
                val color = parseCssColor(css) ?: return@runOnUiThread
                findViewById<View>(R.id.root).setBackgroundColor(color)
                webView.setBackgroundColor(color)
                val light = ColorUtils.calculateLuminance(color) > 0.5
                WindowCompat.getInsetsController(window, window.decorView).apply {
                    isAppearanceLightStatusBars = light
                    isAppearanceLightNavigationBars = light
                }
            }
        }
    }

    /** The debug-only capability harness runs from file:// and is not our origin. */
    private fun isDebugHarness(): Boolean =
        BuildConfig.DEBUG && webView.url?.startsWith("file:///android_asset/") == true

    private fun parseCssColor(css: String): Int? {
        val nums = Regex("[\\d.]+").findAll(css).map { it.value }.toList()
        if (nums.size < 3) return null
        return runCatching {
            Color.rgb(nums[0].toFloat().toInt(), nums[1].toFloat().toInt(), nums[2].toFloat().toInt())
        }.getOrNull()
    }

    // ------------------------------------------------------------------ offline

    private fun wireOfflineRetry() {
        offlineView.findViewById<Button>(R.id.retry_button).setOnClickListener { view ->
            if (errorState == ErrorState.NO_CONNECTION && isOffline()) {
                view.animate().alpha(0.4f).setDuration(90)
                    .withEndAction { view.animate().alpha(1f).setDuration(90).start() }.start()
                return@setOnClickListener
            }
            retryLoad()
        }

        // Come back automatically the moment the network returns.
        val manager = getSystemService(ConnectivityManager::class.java) ?: return
        runCatching {
            manager.registerDefaultNetworkCallback(object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    uiHandler.post { if (errorState != ErrorState.NONE) retryLoad() }
                }
            })
        }
    }

    private fun retryLoad() {
        hideError()
        if (!firstPaintDone) loadingView.visibility = View.VISIBLE
        val current = webView.url
        if (current == null || current.startsWith("about:")) webView.loadUrl(BuildConfig.START_URL)
        else webView.reload()
    }

    /**
     * A load that never finishes is indistinguishable from a frozen app. If nothing
     * has painted after [LOAD_TIMEOUT_MS], stop the load and offer a retry rather
     * than leaving the user staring at a blank screen.
     */
    private fun armLoadWatchdog() {
        disarmLoadWatchdog()
        loadWatchdogArmed = true
        uiHandler.postDelayed(loadWatchdog, LOAD_TIMEOUT_MS)
    }

    private fun disarmLoadWatchdog() {
        loadWatchdogArmed = false
        uiHandler.removeCallbacks(loadWatchdog)
    }

    private val loadWatchdog = Runnable {
        if (!loadWatchdogArmed) return@Runnable
        loadWatchdogArmed = false
        firstPaintDone = true
        // Deliberately NOT stopLoading(): the request may still be crawling in and
        // onPageFinished will clear this screen if it lands. Offer the retry now
        // instead of leaving the user on a blank page indefinitely.
        watchdogTrippedError = true
        showError(if (isOffline()) ErrorState.NO_CONNECTION else ErrorState.SERVER)
    }

    private fun showError(state: ErrorState) {
        errorState = state
        loadingView.visibility = View.GONE
        offlineView.findViewById<android.widget.TextView>(R.id.error_title)
            .setText(if (state == ErrorState.SERVER) R.string.error_server_title else R.string.offline_title)
        offlineView.findViewById<android.widget.TextView>(R.id.error_message)
            .setText(if (state == ErrorState.SERVER) R.string.error_server_message else R.string.offline_message)
        offlineView.visibility = View.VISIBLE
        progressBar.visibility = View.GONE
    }

    private fun hideError() {
        errorState = ErrorState.NONE
        watchdogTrippedError = false
        offlineView.visibility = View.GONE
    }

    /** Terminal state: there is no WebView on this device to render anything in. */
    private fun showWebViewUnavailable() {
        androidx.appcompat.app.AlertDialog.Builder(this)
            .setTitle(R.string.webview_missing_title)
            .setMessage(R.string.webview_missing_message)
            .setCancelable(false)
            .setPositiveButton(android.R.string.ok) { _, _ -> finish() }
            .show()
    }

    private fun isOffline(): Boolean {
        val manager = getSystemService(ConnectivityManager::class.java) ?: return false
        val network = manager.activeNetwork ?: return true
        val caps = manager.getNetworkCapabilities(network) ?: return true
        return !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    private enum class ErrorState { NONE, NO_CONNECTION, SERVER }

    private companion object {
        const val SURFACE_DEFAULT = "#070A12"

        /** Two renderer deaths inside this window means recreating is not helping. */
        const val RENDERER_DEATH_WINDOW_MS = 30_000L

        /** Never hold the launch splash longer than this, whatever the network does. */
        const val SPLASH_MAX_MS = 6_000L

        /**
         * A main-frame load that has not *finished* by now gets a retry offered.
         * Generous on purpose: Uzbek mobile data can genuinely take this long, and
         * a false positive here covers a page that was about to work.
         */
        const val LOAD_TIMEOUT_MS = 30_000L

        /**
         * Reports the page's background colour, then again whenever the theme
         * changes. The web app toggles `data-theme` on <html> without navigating,
         * so a one-shot read would leave the system bars stuck on the old colour.
         */
        const val SURFACE_BRIDGE_JS = """
            (function () {
              if (window.__salomSurfaceBridge) { window.__salomSurfaceBridge(); return; }
              function read() {
                try {
                  var el = document.body || document.documentElement;
                  var c = getComputedStyle(el).backgroundColor;
                  if (c && c !== 'rgba(0, 0, 0, 0)' && c !== 'transparent') SalomNative.onSurfaceColor(c);
                } catch (e) {}
              }
              window.__salomSurfaceBridge = read;
              read();

              // WebView ignores the HTML5 download attribute for renderable types
              // (images), so those links would navigate instead of downloading.
              // Capture-phase listener so the page's own handlers still run.
              if (!window.__salomDownloadHook) {
                window.__salomDownloadHook = true;
                document.addEventListener('click', function (e) {
                  try {
                    var a = e.target && e.target.closest && e.target.closest('a[download]');
                    if (!a || !a.href) return;
                    if (a.href.indexOf('blob:') === 0 || a.href.indexOf('data:') === 0) return;
                    e.preventDefault();
                    SalomNative.download(a.href, a.getAttribute('download') || '');
                  } catch (err) {}
                }, true);
              }

              // Android WebView has no Web Share API. The web app feature-detects
              // it (`if (navigator.share)`), so providing it here restores the
              // share button with a real native sheet instead of a dead control.
              if (!navigator.share) {
                try {
                  Object.defineProperty(navigator, 'share', {
                    value: function (data) {
                      data = data || {};
                      SalomNative.share(data.title || '', data.text || '', data.url || '');
                      return Promise.resolve();
                    },
                    configurable: true
                  });
                } catch (e) {}
              }

              try {
                new MutationObserver(read).observe(document.documentElement, {
                  attributes: true, attributeFilter: ['data-theme', 'class', 'style']
                });
              } catch (e) {}
              setTimeout(read, 400);
            })();
        """
    }
}

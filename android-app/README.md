# Salom AI — Android app

A native Kotlin shell around `https://salom-ai.uz`. The product ships with the web
deploy; this app supplies the native surface — no browser chrome, native
permissions, native downloads, native share, native push, and native Google
Sign-In.

**Built, signed and tested on device.** See [§ What you need to provide](#what-you-need-to-provide).

```
android-app/
├── app/src/main/java/com/feratech/salomai/
│   ├── MainActivity.kt            WebView host, insets, back, offline, sign-in, JS bridge
│   ├── SalomApp.kt                Application — push init
│   ├── web/                       navigation policy, WebView/Chrome clients, files, downloads
│   ├── auth/                      native Google Sign-In + session sync
│   ├── net/SalomApi.kt            the 4 backend calls native code makes itself
│   └── push/PushManager.kt        OneSignal
├── app/src/debug/assets/devtest.html   capability harness (debug builds only)
├── brand/                         source artwork the icon generators read
├── server/assetlinks.json         → publish on salom-ai.uz for App Links (optional, see below)
├── store/                         Play graphic assets + listing copy + form answers
├── tools/                         keystore, icons, store assets, screenshots, Play upload
└── key.properties                 signing secrets — gitignored
```

> The legacy `../android/salom_ai` (Flutter, ~1 GB) and `../android/twa` modules have
> been deleted, along with the stale `android-twa.yml` workflow. Their brand artwork
> now lives in `brand/`, so this project is self-contained. Both are recoverable from
> git history (`0b884f0`) if ever needed.
>
> CI is `.github/workflows/android.yml`: debug build + lint on every push touching
> `android-app/`. Release signing stays off CI — a once-a-year release does not
> justify putting the upload key in a secrets store.

---

## Why a WebView shell and not a TWA

A Trusted Web Activity was built first and rejected for a specific reason: it
renders through Chrome, and Chrome shows a `salom-ai.uz` URL bar until a
`assetlinks.json` file is published on the domain. That is a hard dependency on a
server change, and it makes the app look like a browser until it lands.

This build has no such dependency. It is a real Android app that happens to render
your web UI, and it is better in ways that survive the URL bar question:

| | TWA | This |
|---|---|---|
| Browser chrome | until `assetlinks.json` ships | **never** |
| Permission prompt says | "salom-ai.uz" | **"Salom AI"** |
| Downloads land in | Chrome's list | **Downloads, notification under your app** |
| Push | web push via Chrome | **native OneSignal SDK** |
| `navigator.share` | works | **works** (polyfilled to the Android share sheet) |
| Session storage | shared with Chrome — clearing Chrome logs users out | **isolated to the app** |
| Future native features | impossible | JS↔native bridge in place |

The cost is Google Sign-In, which is handled below.

---

## Google Sign-In — the one genuinely hard part

Google **refuses to serve `accounts.google.com` inside an embedded WebView**
(`disallowed_useragent`). Your login sends users there
(`web/src/store/auth.ts` → `startOAuthRedirect`), so a naive WebView wrapper
breaks Google login on day one.

Instead, `web/NavigationPolicy.kt` intercepts that navigation, cancels it, and
runs **native Google Sign-In** through Credential Manager. The resulting ID token
goes to your existing `POST /auth/oauth/verify`, and the returned session is written
into the WebView's `localStorage` under the same keys the web app already uses.

**This needs no backend change.** `backend/app/config.py:78` already whitelists the
web client ID, and Credential Manager mints tokens whose `aud` is the *server*
client ID you pass it — not the Android one. The Android OAuth client only
authenticates the app; it never appears as the audience.

Apple and Telegram are untouched: Apple does not block WebViews, so that flow stays
in-app (verified), and Telegram links hand off to the Telegram app.

---

## What you need to provide

Two items, neither blocking the build:

### 1. Android OAuth client (required for Google sign-in)

Google Cloud Console → APIs & Services → Credentials → **Create OAuth client ID** →
**Android**:

- **Package name:** `com.feratech.salomai`
- **SHA-1 (upload key):**
  `84:5E:2A:6A:C6:6E:A6:63:91:89:9C:0C:EC:FC:DF:29:96:E7:B2:F8` *(this is the debug key —
  run the command below for the release upload key)*

```sh
/opt/homebrew/opt/openjdk@17/bin/keytool -list -v \
  -keystore ~/salom-ai-upload.keystore -alias salom-ai-upload | grep SHA1
```

Add **both** the upload-key SHA-1 and, after the first Play upload, the **Play App
Signing** SHA-1 (Play Console → Test and release → App integrity). Without the
second one, Google sign-in works in your local builds but fails for Play users.

No backend change. No new client secret.

### 2. OneSignal Android app ID (required for push)

Either create a "Salom AI Android" app in OneSignal (recommended — lets you run
Android-only campaigns) or reuse the iOS one. Then build with:

Add it once to `android-app/local.properties` (gitignored):

```properties
ONESIGNAL_APP_ID=<uuid>
```

`-PONESIGNAL_APP_ID=<uuid>` and the `ONESIGNAL_APP_ID` environment variable also
work. A release build without it still succeeds but prints a loud banner —
shipping without push is a legitimate choice, shipping without it *by accident*
is not.

Push is fully wired and **no-ops cleanly when the id is absent**, which is why the
app builds and runs today without it. Once supplied:

- permission is requested *after* sign-in, never on first launch (Android 13 gives
  you exactly one prompt — burning it on a logged-out stranger is how you lose the
  channel permanently)
- the OneSignal external id is set to the Salom AI user id
- the subscription is registered with `POST /notifications/device` as `platform: "android"`

---

## Build

Requires JDK 17 and the Android SDK (API 36).

```sh
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export ANDROID_HOME=$HOME/Library/Android/sdk

./gradlew :app:assembleDebug      # app/build/outputs/apk/debug/app-debug.apk
./gradlew :app:bundleRelease      # .../bundle/release/app-release.aab   ← Play wants this
./gradlew :app:assembleRelease    # release APK, to test the minified build on a device
./gradlew :app:lintDebug          # 0 errors, 0 actionable warnings
```

Two lint checks are disabled with justification in `app/build.gradle.kts`:
`GradleDependency` (every newer androidx release needs compileSdk 37, which AGP
8.11.1 rejects — bump both together) and `IconLauncherShape` (the pre-API-26 square
icon is a designed full-bleed mark; adaptive icons handle masking from 26 up).

Release: **3.0 MB APK / 4.5 MB AAB**, R8 + resource shrinking, signed.

The AAB was validated the way Play will actually use it — `bundletool build-apks`
→ install → launch — not just by testing the APK. It carries the R8 mapping (Play
deobfuscates crash reports automatically, no separate upload) and a baseline
profile for faster cold start.

Before any upload:

```sh
./tools/preflight.sh
```

### Signing — already done

`tools/create-keystore.sh` generated `~/salom-ai-upload.keystore` (RSA 4096, alias
`salom-ai-upload`) and a gitignored `key.properties` holding the path and password.

> **Back up the keystore and password to 1Password now.** With Play App Signing a
> lost upload key is recoverable through Google support, but that costs days.

A release build with no `key.properties` fails at configuration time rather than
silently producing an unsigned artifact Play rejects.

Upload-key SHA-256:
`33:D9:28:80:B5:57:95:07:BE:3B:0A:8E:9F:FB:27:6F:A3:66:9D:DA:4D:2F:2B:59:5C:EC:B7:4C:37:7F:D2:D0`

---

## What the shell does beyond loading the site

- **Native offline screen** with automatic recovery the instant connectivity
  returns — instead of the WebView's error page.
- **File picker** offering gallery *and* direct camera capture, wired to
  `<input type="file">` (avatar upload, chat/image attachments).
- **Downloads via DownloadManager**: `.pptx`/`.docx` land in Downloads with a
  progress notification under your app's name.
- **Native permission prompts** — "Allow Salom AI to record audio?" rather than a
  page asking on behalf of a domain.
- **Android share sheet**, polyfilled onto `navigator.share`.
- **System bars that follow the web theme**, light or dark, live.
- **Launcher shortcuts** (Yangi chat / Ilovalar), adaptive + round + Android 13
  themed icons, Android 12+ splash held until first paint.
- **Android App Links** so `https://salom-ai.uz/*` opens in the app.
- **Session sync** — Telegram and Apple sign-in happen entirely inside the web app,
  and the shell still picks the session up for push. No web change needed.

## Error handling

Audited case by case and tested on device. Four of these were bugs found *during*
that audit, not designed in:

| Case | Behaviour |
|---|---|
| No network at cold start | Native "No internet connection" screen |
| Network drops mid-session, then the user navigates | Same screen — never a WebView error page |
| Network returns (foreground) | Reloads automatically, no tap needed |
| Network returns while backgrounded, user resumes | Reloads on resume ⚠️ *was a bug — it hid the overlay and revealed a blank WebView* |
| Device online but server unreachable / 5xx / bad TLS | **"Can't reach the server"** — a different message ⚠️ *was a bug — told users with working Wi-Fi to check their internet* |
| Load stalls and never completes | Retry offered after 30 s ⚠️ *was a bug — `onPageCommitVisible` disarmed the timeout as soon as the blank shell painted, so a stalled load hung forever* |
| Very slow network at launch | Splash is capped at 6 s, then hands off to a branded loading screen (logo + spinner) until first paint ⚠️ *was a bug — the splash was held until first paint, so a hanging server froze the app on the splash* |
| A load that recovers after the retry screen appeared | Error screen clears itself — never left covering a working page |
| Renderer process killed (low memory) | `onRenderProcessGone` → activity recreated. A second death within 30 s stops recreating and shows the retry screen, so a device that cannot keep a renderer alive does not spin in a restart loop |
| Android System WebView disabled or mid-update | Explains what to enable instead of crashing at launch |
| Bad certificate | Load cancelled, never click-through-able |
| Sub-resource failure (an image, an ad script) | Ignored — must never blank the whole app |
| Download / file-picker / sign-in failure | Toast, state reset, app stays usable |

Tested against production with the network genuinely disabled, throttled to
GSM/GPRS, and pointed at a refused port — not simulated in code.

**Not force-triggered:** the renderer-kill path (the loop guard above is the mitigation). A JS OOM in the harness was caught
by V8 and a `kill -9` on the renderer is not permitted on a user build. The handler
is the documented one (`return true` + `recreate()`), and the app survived sustained
memory pressure without a crash, but it has not been observed firing.

### Non-obvious implementation notes

Each of these was found by testing, not by reading docs — they are the parts most
likely to be "fixed" back into bugs:

1. **`CAMERA` is deliberately not declared.** Declaring it without holding it makes
   Android refuse to start `ACTION_IMAGE_CAPTURE` outright (*"Permission Denial …
   with revoked permission android.permission.CAMERA"*). The system camera app has
   its own permission. Only add it back if the web app starts using
   `getUserMedia({video:true})`.
2. **`<a download>` is intercepted in JS**, not left to `DownloadListener`. WebView
   ignores the HTML5 `download` attribute for anything it *can* render, so a
   generated image would open in place of downloading.
3. **Insets pad the container, not the WebView.** WebView does not reliably inset
   its rendered page from its own padding — content drew under the status bar.
   (The site's viewport meta has no `viewport-fit=cover`, so `env(safe-area-*)` is
   0 inside a WebView and the bottom tab bar would otherwise sit under the gesture pill.)
4. **A cancelled Google sign-in reloads the login page.** The web button has already
   switched to "Redirecting to Google…" by the time we cancel the navigation, and
   its spinner would otherwise stay stuck forever.
5. **The camera capture URI grant is explicit** (`ClipData` + read/write flags).
   Android logs that the implicit `EXTRA_OUTPUT` grant "will be discontinued from
   Android 18", which would silently break photo capture on a future OS.
6. **The JS bridge is origin-checked on every call.** It is exposed to every page
   the WebView loads, including Click/Payme checkout.
7. **`res/raw/keep.xml` protects the push icon from resource shrinking.** OneSignal
   resolves `ic_stat_onesignal_default` by name at runtime, so R8 sees no reference
   and `isShrinkResources` would strip it — every notification would then fall back
   to the full-colour launcher icon, which Android renders as a white blob.

---

## Verified on device

Pixel 9 Pro XL emulator, API 37, Google Play system image, against **production**
`salom-ai.uz`, with the **signed R8-minified release build** unless noted:

| | |
|---|---|
| Full screen, no browser chrome | ✅ |
| Site loads, renders, navigates | ✅ |
| Google button → native Credential Manager, **0 WebView navigations to accounts.google.com** | ✅ (survives R8) |
| Cancelled sign-in leaves the login screen usable | ✅ |
| Apple sign-in renders in-app on `appleid.apple.com` | ✅ |
| Camera → photo → delivered to `<input type="file">` | ✅ `capture_….jpg 63 KB image/jpeg` |
| File chooser offers Camera + Files | ✅ |
| Download → `/sdcard/Download/salom-test.png` + completion notification | ✅ |
| Microphone → **"Allow Salom AI to record audio?"**, `RECORD_AUDIO granted=true` | ✅ |
| `navigator.share` → Android share sheet | ✅ |
| System bars follow page surface colour (white page → dark icons) | ✅ |
| Offline → native screen; auto-recovers when network returns | ✅ |
| Deep link `https://salom-ai.uz/about` opens in app | ✅ |
| Back: page history, then exits cleanly | ✅ |
| Release build: 0 crashes, 0 `ClassNotFound`/`NoSuchMethod` | ✅ |
| Lint | ✅ 0 errors |

**Not verifiable here, needs a real device or an account:**

- **Actual microphone capture.** The permission bridge is proven (`granted=true`,
  and `getUserMedia` failed with `NotReadableError`, not `NotAllowedError`), but the
  emulator reports `Input device: 0 (AUDIO_DEVICE_NONE)` — it has no microphone.
  Run the realtime voice flow on a physical phone.
- **Everything behind login** — chat streaming, presentation/referat generation and
  their `.pptx`/`.docx` downloads, image upload, the paywall. The bridges these use
  are all covered by the harness below, but the end-to-end product flows need an
  account.
- **Google sign-in completing** — needs the Android OAuth client from §1.
- **Push delivery** — needs the OneSignal app id from §2.

### Capability harness

Debug builds ship a self-test page that exercises every native bridge without an
account:

```sh
adb shell am start -n com.feratech.salomai/.MainActivity -e devtest 1
```

File picker · downloads · microphone · share sheet · system-bar theming · a full
environment dump. Use it for regression checks after any change.

---

## Release

The Google Play Publishing API **cannot create an app** — the listing and first
upload are manual. Everything after that is scripted.

1. **Play Console → Create app** — `Salom AI`, default language **O'zbek (uz)**, App, Free.
2. **Internal testing → Create release** → upload `app/build/outputs/bundle/release/app-release.aab`.
   Accept **Play App Signing**.
3. **Copy the Play App Signing SHA-1** into the Google Cloud Android OAuth client (§1),
   or Google sign-in will fail for everyone who installs from Play.
4. **Store listing** — copy and form answers are written for you in `store/listing.md`;
   assets in `store/`. Screenshots: `./tools/capture-screenshots.sh 01-chat`.
5. **App access** — reviewers cannot receive an Uzbek SMS or use your Telegram bot.
   Supply working credentials or they will reject on that alone.
6. Internal → closed → production, staged 10% → 50% → 100%.

Personal Play accounts created after 13 Nov 2023 also need **12 testers opted in for
14 continuous days** before production access. Organisation accounts are exempt.

### Subsequent releases

```sh
# bump versionCode in app/build.gradle.kts, then:
./tools/preflight.sh                 # builds, checks, and lists what is left
export PLAY_SERVICE_ACCOUNT_JSON=~/salom-ai-play-service-account.json
python3 tools/upload-to-play.py --track internal
python3 tools/upload-to-play.py --track production --rollout 0.1
```

`versionCode` starts at **10** — the earlier shells used 1 and 2 locally, and Play
burns a version code permanently once uploaded to any track.

### How often you actually have to release

| Change | New release? |
|---|---|
| Any web change — features, UI, copy, pricing, paywall, i18n | ❌ never |
| Backend / admin panel / iOS | ❌ never |
| App icon, name, colours, start URL, a new permission | ✅ |
| **Annual target-SDK bump** (API 36 → 37 …, each 31 Aug) | ✅ ~once a year |

`targetSdk` is already 36, satisfying Play's 31 Aug 2026 requirement.

---

## Optional: `assetlinks.json`

Not required for the app to look or work correctly — it is only needed so Android
**App Links** open `https://salom-ai.uz/*` links directly in the app instead of
showing a chooser. Instructions and the ready-to-copy file are in `server/README.md`.

---

## Tools

| Script | Purpose |
|---|---|
| `tools/preflight.sh` | **Run before every release.** Signing, versionCode, targetSdk, lint, AAB contents, signature — plus the checklist only you can finish. |
| `tools/create-keystore.sh` | One-time upload keystore + `key.properties`. Already run. |
| `tools/generate_icons.py` | Regenerate every launcher/splash/notification raster from the brand artwork. |
| `tools/generate_store_assets.py` | Play icon (512²) and feature graphic (1024×500). |
| `tools/capture-screenshots.sh` | Play-compliant screenshots (crops to the 2:1 max aspect ratio). |
| `tools/upload-to-play.py` | Upload an AAB to a track via the Play Developer API. |

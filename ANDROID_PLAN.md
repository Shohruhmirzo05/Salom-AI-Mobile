# Salom AI — Android (Google Play) Architecture Analysis & Plan

> **Superseded by the built app — and §2 was overruled.** The shipped Android app
> is a **native Kotlin WebView shell**, not the Trusted Web Activity this document
> recommended. A TWA was built first and rejected: it shows a `salom-ai.uz` URL bar
> until `assetlinks.json` is published, which made the app read as a browser and put
> the look-and-feel behind a server change. The WebView shell has no such dependency
> and is better on push, permissions, downloads and session isolation. Google
> Sign-In — the one real objection to WebView, and the reason §2 chose TWA — is
> solved with native Credential Manager and needs **no backend change**.
>
> Read **`android-app/README.md`** for what shipped. This document is kept for the
> Play Console research (§7) and the web-side findings (§4.2, §4.3).
>
> Payments and Play billing policy are handled by the owner and are out of scope for
> the Android work, so §5 does not reflect what was built.

**Date:** 2026-07-24
**Goal:** ship one Android app to Google Play that wraps `salom-ai.uz`, feels native, and needs
(essentially) no further Play releases while web / backend / admin / iOS keep shipping daily.

---

## 0. Executive summary

**Recommendation: keep the Trusted Web Activity (TWA) approach, delete the Flutter app, and fix
the six concrete blockers listed in §4 before submitting.**

A TWA scaffold already exists at `android/twa/` (committed in `0b884f0`). It is the right
architecture, but **it will not work as-is** — it is missing the `asset_statements` manifest entry,
the server is not serving `assetlinks.json`, and there is no notification delegation. I verified
these against the live site, not just the source.

Two findings that change the shape of the project:

1. **Google Play will not let you sell Standard/Pro through Click/Payme inside the Android app.**
   Uzbekistan *is* a supported Play merchant country, so the "we can't use Play Billing" exemption
   does not apply to you. Subscriptions bought in-app must use Google Play Billing (15% cut, and
   Uzcard/Humo are not accepted by Google). The external-payment-links program is US/UK/EEA only.
   → **v1 Android must be "consumption-only": no purchase CTAs, no checkout links.** Detailed
   options and the recommended detection mechanism are in §5.

2. **"Push once and never update again" is not fully achievable.** Google Play forces a target-SDK
   bump every year (API 36 by **31 Aug 2026**, API 37 in 2027, …). Realistically you will do
   **one ~10-minute Android release per year** and nothing else. Everything product-facing —
   UI, paywall, i18n, features, pricing — ships from the web with zero Play involvement. §6 explains
   how to make the shell "capability-complete" so nothing *else* ever forces a release.

Also worth knowing up front: **web push is currently broken on salom-ai.uz** (§4.3). That matters
because push is the single biggest reason a wrapper app is allowed on Play at all, and it is the
main retention lever you'd gain from an Android install.

---

## 1. What exists today

### 1.1 Repo layout

```
Untitled/
├── Salom-AI/                  backend (FastAPI) + web (React/Vite) + admin-panel + infra
├── Salom-AI-Mobile/           iOS (SwiftUI, native) + android/  ← this plan
├── Salom-AI-TelegramBot/      Telegram bot (python)
└── Business/                  separate B2B product (out of scope)
```

### 1.2 `Salom-AI-Mobile/android/` — two things live here

| Path | What it is | Verdict |
|---|---|---|
| `android/salom_ai/` | Full **Flutter** app: Supabase, Riverpod, go_router, OneSignal, realtime voice over WS, file_picker, google_sign_in. Version `1.0.0+1`. Has a complete `PUBLISH_PLAY_STORE.md` runbook. **Never published.** | **Delete.** ~30 native deps to maintain, duplicates the web feature set, still on Supabase auth (the backend moved on), and every web feature change would need a Play release — the exact opposite of the goal. |
| `android/twa/` | **Trusted Web Activity** shell using `androidbrowserhelper:2.6.2`, `applicationId com.feratech.salomai`, plus a working CI job at `.github/workflows/android-twa.yml`. | **Keep and fix.** Right architecture, incomplete implementation (§4). |

The Flutter app's `PUBLISH_PLAY_STORE.md` is still a genuinely useful Play Console runbook —
**salvage the text, drop the Flutter build steps.**

Note the Flutter app used package `com.feratech.salomai` and so does the TWA. Since nothing was
ever published, the package name is still free to change if you want (e.g. `uz.salomai.app`) —
but there's no reason to; keep `com.feratech.salomai`.

### 1.3 The web app — what the shell will actually be running

`Salom-AI/web` — React 18 + Vite 6 + Tailwind + react-router 6. 93 source files.

Already mobile-native in shape, which is why this works:

- `src/components/BottomNav.tsx` — 3-tab native-style bottom bar, `md:hidden`, respects
  `env(safe-area-inset-bottom)`.
- `src/pages/App.tsx` — every heavy route is `lazy()`-split behind `<Suspense>`; dark splash in
  `index.html` before the bundle parses, so there is no white flash on cold start.
- `src/pages/App.tsx:238` — already handles `?target=apps` and client-side redirects to `/apps`,
  which is exactly what the TWA launch URL uses.
- `public/manifest.webmanifest` — valid, `display: standalone`, 192/512 maskable icons,
  `start_url: /?source=pwa&target=apps`, app shortcuts defined. **Verified live: HTTP 200,
  `application/manifest+json`.**

Web features the shell has to support, and how they behave in a TWA:

| Feature | Web implementation | In a TWA |
|---|---|---|
| Google sign-in | `store/auth.ts` → full-page redirect to `accounts.google.com` (`response_type=id_token`) | ✅ Works — TWA *is* Chrome. **This is the single decisive reason not to use a WebView** (Google blocks OAuth in embedded WebViews with `disallowed_useragent`). |
| Apple sign-in | redirect to `appleid.apple.com`, returns to `/login` | ✅ Works |
| Telegram login | phone → `window.open('https://t.me/…')` → 6-digit code | ✅ Opens the Telegram app via Android App Links; user switches back manually |
| Realtime voice | `lib/realtime-voice.ts:374` `getUserMedia({echoCancellation…})` + WSS to `/ws/voice/…` | ✅ Chrome prompts for mic per-origin. No Android permission needed in your manifest — Chrome owns it. |
| File / image upload | `pages/Settings.tsx:403` `<input type="file" accept="image/*">`, `pages/Images.tsx:52` FormData | ✅ Chrome's picker, incl. camera |
| Download .pptx/.docx | `PresentationEditor.tsx:305`, `ReferatEditor.tsx:160` `<a download>` | ✅ Chrome download manager |
| Share | `PresentationEditor.tsx:259` `navigator.share()` | ✅ Web Share API works in Chrome |
| Push | `react-onesignal` v3, `lib/webPush.ts`, `main.tsx` | ⚠️ **Currently broken — see §4.3** |
| Ads | Yandex autoplacement, `lib/ads.ts` — `YANDEX_ENABLED = false` (site rejected by YAN moderation, re-submit after 2026-07-18) | Off today. If re-enabled, declare "contains ads" in Play Console. |
| Payments | `PaymentMethodModal.tsx` → Click/Payme redirect, return via `visibilitychange` polling | 🚫 **Policy problem — see §5** |
| Account deletion | `pages/Settings.tsx:84` → `DELETE /account` (`backend/app/routers/account.py:82`) | ✅ Satisfies Play's in-app deletion requirement; you additionally need a *public web URL* for the Data-safety form (§7.4) |

### 1.4 Backend — already Android-aware

- `backend/app/routers/events.py:22` — `VALID_PLATFORMS = {"web", "ios", "telegram", "android"}` ✅
- `backend/app/models.py:512` — device platform column comments already list `android` ✅
- `backend/app/routers/subscriptions.py:433` `_generate_return_url()` — branches on `telegram` /
  `ios`, else falls through to the generic web result page. Android would correctly use the web
  branch. **No backend change is required for v1.** (An `android` branch is only worth adding for
  attribution cleanliness later.)

**Conclusion: the backend needs zero changes.** Good — it's being worked on by another agent.

### 1.5 Infra

`Salom-AI/infra/nginx.conf` → host nginx terminates TLS for `salom-ai.uz` and proxies `/` to the
`web` container. The web container's `web/nginx.conf` does
`try_files $uri $uri/ $uri/index.html /index.html`.

Consequence: **any file that doesn't exist silently returns `index.html` with HTTP 200.** That is
exactly what's biting `assetlinks.json` and the OneSignal worker today (§4.2, §4.3). Both failures
are silent — you get a 200, not a 404.

---

## 2. Architecture decision

| Option | Verdict |
|---|---|
| **TWA (`androidbrowserhelper`)** | ✅ **Recommended.** Runs in Chrome → OAuth works, shares Chrome's cookie jar and storage, gets Chrome's updates for free, ~2 MB APK, essentially zero code to maintain. Google's own supported path for putting a web app on Play. |
| WebView wrapper (Capacitor / Median / raw WebView) | ❌ Google OAuth is blocked in embedded WebViews — your primary login breaks. Fixable only by routing OAuth out to Custom Tabs, which adds exactly the native complexity you're trying to avoid. Also the #1 target of Play policy 4.3 (Minimum Functionality) rejections. |
| Keep Flutter | ❌ Every web change needs a Play release. Directly contradicts the goal. |
| React Native / native rewrite | ❌ Same objection, higher cost. You already have a native app on iOS; a second native codebase is not the ask. |

**Trade-offs you are accepting with TWA (all acceptable here):**

- No JS↔native bridge. No native AdMob rewarded ads on Android (iOS has `RewardedAdManager`;
  Android would rely on Yandex web ads instead). `lib/ads.ts:watchAdForReward()` already returns
  `null` on web, so the reward button simply hides — no work needed, just a known parity gap.
- Requires Chrome (or another TWA-capable browser) installed and reasonably current. Chrome ships
  on effectively every Play-certified device in Uzbekistan; on the rare device without it,
  `androidbrowserhelper` falls back to a Custom Tab with a visible URL bar. Degraded, not broken.
- Storage lives in Chrome. If a user clears Chrome's data, they're logged out of the app too.
- No native splash beyond the TWA splash image + the `index.html` dark splash (which is already good).

---

## 3. What the shipped app looks like

```
User taps "Salom AI" icon
  → LauncherActivity (androidbrowserhelper)
  → Android verifies Digital Asset Links against
    https://salom-ai.uz/.well-known/assetlinks.json
  → Chrome renders https://salom-ai.uz/?source=android_twa&target=apps
    full-screen, no URL bar, your status/nav bar colours
  → App.tsx:238 sees target=apps → routes to /apps (or /chat if already signed in)
  → Everything from here is your normal web app, updated by your normal `git push`
```

Out-of-scope navigations (`click.uz`, `payme.uz`, `t.me`, `accounts.google.com`) open in a Chrome
Custom Tab with a toolbar and return to the trusted surface when they land back on `salom-ai.uz`.
That's correct, expected TWA behaviour.

---

## 4. Blockers found (concrete)

### 4.1 🔴 P0 — `asset_statements` meta-data is missing → the URL bar will never go away

`android/twa/app/src/main/AndroidManifest.xml` declares `DEFAULT_URL`, splash and status-bar
colours, but **not** the `asset_statements` meta-data that `androidbrowserhelper` requires to
attempt verification:

```xml
<!-- MISSING from <application> -->
<meta-data android:name="asset_statements" android:resource="@string/asset_statements" />
```

…with a matching `strings.xml` entry pointing at `https://salom-ai.uz`. Without it the app opens
as a plain Custom Tab with a visible address bar — it will look like a browser, not an app, and is
a strong Play policy 4.3 rejection candidate.

### 4.2 🔴 P0 — `assetlinks.json` is not on the server

Verified live:

```
GET https://salom-ai.uz/.well-known/assetlinks.json
→ HTTP 200, content-type: text/html, 18078 bytes   ← this is index.html
```

The file does not exist; nginx's SPA fallback returns the app shell. Digital Asset Links
verification fails, silently.

`android/twa/assetlinks.template.json` exists with a `REPLACE_WITH_PLAY_APP_SIGNING_SHA256`
placeholder, but nothing publishes it. The fingerprint must come from **Play Console → App
integrity → App signing key certificate (SHA-256)** *after* the first AAB upload — not from your
local upload keystore.

Because the fallback returns 200-with-HTML rather than 404, a typo here is invisible. Add an
explicit nginx location so a mistake fails loudly:

```nginx
location = /.well-known/assetlinks.json {
  default_type application/json;
  try_files $uri =404;
}
```

(There is already exactly this pattern for `apple-app-site-association` in `web/nginx.conf` — mirror it.)

### 4.3 🔴 P0 — web push is broken today, so notification delegation would deliver nothing

Verified live:

```
GET https://salom-ai.uz/OneSignalSDKWorker.js
→ HTTP 200, content-type: text/html, 18078 bytes   ← index.html again
```

`react-onesignal` v3 (OneSignal Web SDK v16) needs `OneSignalSDKWorker.js` served from your origin
at root scope. It is not in `web/public/` and not in `web/dist/`. Service-worker registration
fails → nobody is subscribed → your entire web push channel is dead, on web *and* in the future
Android app.

This is a **web-side bug that exists independently of Android**, and it is worth fixing regardless.
It should be handed to whoever owns the web repo.

Separately, the Android side needs notification delegation, which the current manifest does not have:

- `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />` ✅ (already present)
- a `DelegationService` extending `com.google.androidbrowserhelper.trusted.DelegationService`
  declared with the `android.support.customtabs.trusted.TRUSTED_WEB_ACTIVITY_SERVICE` intent filter ❌ missing
- `<meta-data android:name="android.support.customtabs.trusted.ENABLE_NOTIFICATION" android:value="true" />` ❌ missing

Also note the known Bubblewrap/Android 13 behaviour: the `POST_NOTIFICATIONS` runtime permission is
**not** granted automatically. The web app must trigger the permission request through OneSignal's
prompt after login — `store/auth.ts:registerDevice()` already calls `OneSignal.Slidedown.promptPush()`,
so once §4.3's worker is fixed this should chain correctly. Verify on a real Android 13+ device.

### 4.4 🟠 P1 — `targetSdk 35` must become `36`

`android/twa/app/build.gradle.kts` has `compileSdk = 36` but `targetSdk = 35`.

New apps submitted after **31 Aug 2026** must target API 36. You'd be submitting right at that
boundary, and since the whole point is not to touch this again, set `targetSdk = 36` now.

### 4.5 🟠 P1 — no signing configuration

`build.gradle.kts` has no `signingConfigs`. `./gradlew :app:bundleRelease` produces an unsigned
bundle that Play will reject. Needs an upload keystore + `key.properties` (gitignored) — the Flutter
runbook's §0.1/§0.2 covers this correctly and can be reused verbatim.

The CI job at `.github/workflows/android-twa.yml` only builds `assembleDebug`. Fine for PR checks;
release signing should stay local/manual for a once-a-year release rather than putting a keystore in CI.

### 4.6 🟡 P2 — icon and polish gaps

- Only `res/drawable/app_icon.png` exists. No `mipmap-anydpi-v26` adaptive icon → on Android 8+
  the launcher icon won't be masked correctly and will look off next to native apps.
- `styles.xml` uses `Theme.Material.Light.NoActionBar` with dark bars — works, but the light parent
  with `windowLightStatusBar=false` is inconsistent; prefer a `.NoActionBar` dark parent.
- No `ManageSpaceActivity` (lets users clear the site's data from Android settings — nice-to-have).
- No `FileProvider` authority meta-data, so web-initiated *sharing of files* out of the app may fall
  back rather than using the native share sheet. `navigator.share({url})` (which is what
  `PresentationEditor.tsx:259` uses — URL only, no file) is unaffected.

### 4.7 🟡 P2 — no service worker at all → poor offline behaviour

There is no app service worker anywhere in `web/` (only the missing OneSignal one). Offline, the
TWA shows Chrome's dinosaur error page inside your app frame. That is both a bad experience and a
recurring Play 4.3 talking point ("what does this add over the mobile browser?").

A minimal offline fallback page — cache `index.html`, the dark splash CSS, the logo, and serve them
on navigation failure — is ~40 lines and would meaningfully strengthen the submission.

*(Note: TWA itself does **not** require PWA installability, only Digital Asset Links. The service
worker is for offline quality, not a hard gate.)*

### 4.8 🟡 P2 — `?target=apps` when signed out

`App.tsx:238` redirects to `/apps`, which sits inside `LayoutWrapper`. A signed-out cold start
therefore bounces through a protected route to `/login`. Works, but adds a flash. Worth checking
whether launching signed-out users straight at `/login` (or the landing page) reads better as an
app first-run.

---

## 5. The real decision: Google Play billing policy

This is the part that most affects the business, so it's worth being precise.

### 5.1 What the policy actually says

Google's Payments policy requires Google Play Billing for **"subscription services (such as fitness,
game, dating, education, music, video, or other content subscription services)"** and **"app
functionality or content"**. Salom AI Standard/Pro is squarely inside that.

The published exemptions (physical goods, physical services, P2P payments, 1:1 online paid
services, insurance, gift cards, etc.) **do not cover you**.

Three things I checked specifically, because they're the usual escape hatches:

1. **"We can't use Play Billing from Uzbekistan."** False. Google's supported-locations table lists
   Uzbekistan with ✔ for both developer *and* **merchant** registration (default currency USD).
   The technical-impossibility argument is not available to you.
2. **External payment links program.** Real, but **US / UK / EEA only**, starting 30 Jun 2026. Not
   applicable to an Uzbekistan-targeted app.
3. **Consumption-only / multi-platform access.** ✅ **This one does apply.** Google explicitly
   permits apps where "a user could log in when the app opens and access content paid for somewhere
   else." You may even say *"You can subscribe on our website"* in text — you may **not** link to it
   from inside the app.

### 5.2 Why Play Billing is bad for you commercially, even where it's allowed

- **Fee:** 15% on subscriptions vs. ~1–2% for Click/Payme. At your volume that is a large, permanent
  margin hit on the Android channel.
- **Card coverage:** Uzbek consumers pay with **Uzcard/Humo**, which Google Play does not accept.
  Google Play in Uzbekistan effectively means an international Visa/Mastercard. Conversion would be
  a fraction of Click/Payme.
- It contradicts a documented strategy rule in `Salom-AI/CLAUDE.md`: *"Keep Payme/Click; avoid
  Telegram Stars on mobile (30% Apple/Google cut kills the margin moat)."* The same logic applies
  verbatim to Play Billing.

### 5.3 The three options

| Option | Compliance | Revenue | Effort | Verdict |
|---|---|---|---|---|
| **A. Consumption-only Android** — hide all purchase CTAs and checkout links when running in the TWA. Users subscribe on web / Telegram / iOS and the Android app honours it. | ✅ Explicitly permitted | Android = retention & engagement channel; conversion happens on your existing funnels (Telegram bot is already the paid funnel) | Web-side feature flag, ~1 day | ✅ **Recommended for v1** |
| **B. Google Play Billing via Digital Goods API + Payment Request API** | ✅ Fully compliant | Monetises Android directly, but −15% and poor UZ card coverage | Play Console products, web-side DGA/PRA integration, backend receipt verification against the Play Developer API, dual-entitlement reconciliation with Payme/Click. Multi-week. | 🔶 Phase 2, only if Android proves it can convert |
| **C. Ship Click/Payme inside the Android app anyway** | ❌ Violates the Payments policy | — | — | ❌ Risks removal of the app and, in the worst case, the developer account. Not worth it. |

### 5.4 ⚠️ The detection trap (this one is easy to get wrong)

The obvious implementation of Option A — "set a flag when `?source=android` is seen and store it" —
**is broken**, and it's worth understanding why before anyone writes it.

A TWA runs inside Chrome and **shares Chrome's cookie jar and `localStorage` for `salom-ai.uz`**.
If you persist "this is Android" to `localStorage`, that flag is also visible when the same user
later opens salom-ai.uz in a normal Chrome tab — and you would silently hide the paywall from a
paying web user on the same device. That's a direct revenue leak, and it would be very hard to
diagnose from analytics.

The correct signal is a combination that never persists across surfaces:

```
isAndroidShell =
     new URLSearchParams(location.search).get('source') === 'android_twa'
  || sessionStorage.getItem('salom_shell') === 'android_twa'   // sessionStorage is per-tab, NOT shared
```

set once on entry, plus `matchMedia('(display-mode: standalone)')` as a secondary confirmation.

Note the launch URL should change from today's `?source=android` to a **distinct**
`?source=android_twa`, because the installed PWA already uses `?source=pwa` and both report
`display-mode: standalone`. You want to gate the *Play-distributed* shell only — the browser-installed
PWA is not distributed by Google and should keep its paywall.

**What must be hidden when `isAndroidShell`:** the `Paywall` popup's purchase buttons,
`PaymentMethodModal`, `CardInputModal`, `SubscriptionPanel`'s upgrade path, `UpgradeNudge`,
`WinBackOfferModal`, `RewardedMessageButton`, and the `/plans` redirect. Free-tier limits still
apply — users just see "this is a Pro feature" without a way to buy, which is what the policy
permits. Existing subscribers see full functionality.

---

## 6. "Push once, never update" — what's actually true

| Change | Needs a Play release? |
|---|---|
| Any web UI, feature, copy, pricing, i18n, paywall change | ❌ No |
| Backend / admin panel / iOS changes | ❌ No |
| App icon, app name, splash colours, launch URL | ✅ Yes |
| New Android runtime permission | ✅ Yes |
| Turning on Play Billing later | ✅ Yes — **unless you pre-wire it now** |
| **Annual target-SDK bump (API 36 → 37 → …)** | ✅ **Yes, ~once a year, unavoidable** |

So: **~1 release/year, ~10 minutes each.** That is as close to "never" as Google permits.

### The capability-complete shell

To make sure nothing *other than* the annual bump ever forces a release, wire every capability you
might plausibly want **into v1, dormant**:

- **Notification delegation** — on (needed anyway).
- **Play Billing delegation** — add `com.android.vending.BILLING` permission and the
  `androidbrowserhelper:billing` `PlayBillingServiceProvider` in the `DelegationService`. Once this
  is in the shell, switching to Option B later is **100% web-side + Play Console** — no new AAB.
  This is the single highest-leverage thing to include, precisely because you don't plan to use it yet.
- **Location delegation** — costs nothing, avoids a release if a future mini-app wants geolocation.
- **`FileProvider`** for native file sharing.
- **`ManageSpaceActivity`.**
- Generous launch-URL design: keep the launch URL a stable root (`/?source=android_twa`) and let
  the React router decide the destination, exactly as `App.tsx:238` already does. Never bake a
  feature path into `strings.xml`.

---

## 7. Implementation plan

### Phase 0 — Decisions (you) — before any code

1. Confirm **Option A** (consumption-only Android) for v1. ← the one real product decision
2. Confirm the Play Console account: does Fera Tech have one, and is it an **organization** or a
   **personal** account? This changes the timeline by two weeks (§7.5).
3. Confirm package name stays `com.feratech.salomai`.
4. Confirm the Android app should launch to `/apps` (the Ilovalar hub) vs `/chat`.

### Phase 1 — Web-side prerequisites (`Salom-AI` repo — coordinate with the agent working there)

| # | Task | Why |
|---|---|---|
| 1.1 | Add `web/public/.well-known/assetlinks.json` (fingerprint filled in after first Play upload) + explicit nginx `location =` block | §4.2 — hard blocker |
| 1.2 | Fix OneSignal: add `OneSignalSDKWorker.js` to `web/public/`, verify SW registration, verify a real push lands | §4.3 — hard blocker, **and a live web bug today** |
| 1.3 | Add `isAndroidShell` detection (`lib/shell.ts`) using the sessionStorage approach from §5.4 | §5.4 |
| 1.4 | Gate all purchase surfaces behind `!isAndroidShell` | §5.3 Option A |
| 1.5 | Minimal service worker with an offline fallback page | §4.7 — Play 4.3 quality |
| 1.6 | Optional: skip the synchronous `telegram-web-app.js` `<script>` in `index.html` when not in Telegram | Small cold-start win; blocking third-party request on every Android launch |

**1.1 and 1.2 are the two that will silently fail if skipped.** Both must be verified with `curl`
against production, not just by reading the diff.

### Phase 2 — Android shell (`Salom-AI-Mobile/android/twa`)

| # | Task |
|---|---|
| 2.1 | Add `asset_statements` string + `<meta-data>` (§4.1) |
| 2.2 | Add `DelegationService` + `ENABLE_NOTIFICATION` meta-data (§4.3) |
| 2.3 | Add billing / location delegation, dormant (§6) |
| 2.4 | `targetSdk = 36` (§4.4) |
| 2.5 | Signing config + gitignored `key.properties` (§4.5) |
| 2.6 | Adaptive icon (`mipmap-anydpi-v26` + foreground/background), dark theme parent, monochrome icon for themed icons (§4.6) |
| 2.7 | `FileProvider` + `ManageSpaceActivity` |
| 2.8 | Bump `versionCode`/`versionName` to a clean `1` / `1.0.0` for the first public release (currently 2 / 1.1.0, inherited from the unpublished Flutter shell — harmless either way, but 1/1.0.0 is cleaner for a first listing) |
| 2.9 | Delete `android/salom_ai/` entirely; keep the Play Console runbook text |

### Phase 3 — Verification (real device, not emulator)

- Digital Asset Links verified → **no URL bar**. Check with
  `adb shell dumpsys package d` or by simply observing the toolbar.
- Google sign-in end to end.
- Apple sign-in end to end.
- Telegram phone → bot → code login, including the app switch back.
- Realtime voice: mic prompt, Uzbek STT, backgrounding mid-call, incoming phone call.
- Presentation generation → `.pptx` download → opens in a document app.
- Image upload from camera and from gallery.
- Push: opt-in prompt on Android 13+, then a real campaign delivered while backgrounded.
- Existing subscriber: Pro features unlocked, **no purchase UI visible anywhere**.
- Free user: limits enforced, paywall shows value but offers no purchase path.
- Airplane mode → offline fallback page, not a Chrome error.
- Android back button through several routes, and out-of-scope round-trip (t.me → back).

### Phase 4 — Play Console

Reuse `android/salom_ai/PUBLISH_PLAY_STORE.md` §2–§4 (store listing, content rating, data safety,
staged rollout). It is accurate apart from the Flutter build commands. Specific items for this app:

- **Data safety:** email, phone, name, audio (for transcription), photos/files, app interactions.
  Declare a **public account-deletion URL** — Play wants a web-accessible request path, not only
  the in-app button at `Settings.tsx:534`. `/settings` is behind auth; a short public page
  (or a section in `/privacy-policy`) explaining deletion satisfies this.
- **Ads:** "No" today (`YANDEX_ENABLED = false`). Must be updated if YAN moderation passes.
- **App access:** provide reviewer credentials — Play reviewers cannot receive an Uzbek SMS or use
  your Telegram bot. Give them a Google account or a bypass number. *(The Flutter runbook mentions
  a dev bypass number `+998996508589` — confirm it still exists on the backend before relying on it.)*
- **Target audience:** 13+.
- Staged rollout: internal → closed → production at 10% → 50% → 100%.

### 7.5 Timeline

| | Organization Play account | Personal account created after 13 Nov 2023 |
|---|---|---|
| Phase 1 + 2 build | 2–3 days | 2–3 days |
| Phase 3 testing | 1–2 days | 1–2 days |
| Closed testing gate | not required | **12 testers, opted in, 14 continuous days** |
| Review | 1–7 days | 1–7 days |
| **Total** | **~1–2 weeks** | **~4 weeks** |

If the account is personal, start recruiting the 12 testers on **day 1** — that clock runs in
parallel with everything else and is otherwise the critical path.

---

## 8. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Play 4.3 "Minimum Functionality" rejection (webview wrapper) | Medium | TWA + verified Digital Asset Links + push + offline fallback + app shortcuts is the documented compliant pattern. If rejected, the appeal cites: it's a TWA on a real PWA, with push, offline support and native navigation — not a WebView. |
| Payments policy strike | Low **if** Option A is implemented correctly | The §5.4 detection must be correct and tested. A single leaked "Buy" button in the Android shell is the whole risk. |
| Digital Asset Links misconfigured → URL bar visible | Medium (silent failure mode) | Explicit nginx `location =` block; verify with `curl` **and** on a real device before submitting. |
| Push still broken after §4.3 fix | Medium | Verify a real delivered notification on a real device before submission — not just successful SW registration. |
| Losing the upload keystore | Low / catastrophic | Enroll in **Play App Signing**, back the upload key up to 1Password. Without it you can never update `com.feratech.salomai` again. |
| Chrome absent or ancient on a user's device | Low | `androidbrowserhelper` falls back to a Custom Tab. Degraded, functional. |
| Web team ships a change that breaks the shell | Low | The shell only depends on: origin stays `salom-ai.uz`, manifest scope stays `/`, `?target=apps` keeps working, `assetlinks.json` keeps being served. Worth a line in `Salom-AI/CLAUDE.md`. |
| Android reviewer can't sign in | Medium | Reviewer credentials in "App access" — easy to forget, common rejection cause. |

---

## 9. Open questions for you

1. **Play Console account** — does one exist? Organization or personal? *(drives the timeline)*
2. **Option A confirmed?** Android as a retention/engagement surface with no in-app purchasing, at
   least for v1. If you'd rather monetise Android from day one, that's Option B and a multi-week
   project — but the shell should still be built capability-complete either way.
3. **Is `+998996508589` still a working dev-bypass number** for Play reviewers?
4. **Launch destination** — `/apps` (Ilovalar hub, current TWA config) or `/chat`?
5. Should I also fix the **OneSignal web-push bug** (§4.3)? It's a live web-side defect affecting
   web and Telegram users today, independent of Android — but it's in the repo another agent is
   working in, so it needs coordination.

---

## Appendix — sources

- [Understanding Google Play's Payments policy](https://support.google.com/googleplay/android-developer/answer/10281818)
- [Supported locations for developer and merchant registration](https://support.google.com/googleplay/android-developer/answer/9306917) (Uzbekistan: developer ✔, merchant ✔)
- [External payment links — About the program](https://developer.android.com/google/play/billing/externalpaymentlinks) (US/UK/EEA)
- [Target API level requirements for Google Play apps](https://support.google.com/googleplay/android-developer/answer/11926878) (API 36 by 31 Aug 2026)
- [Trusted Web Activity integration guide](https://developer.chrome.com/docs/android/trusted-web-activity/integration-guide) (`asset_statements`)
- [Use Play Billing in your Trusted Web Activity](https://developer.chrome.com/docs/android/trusted-web-activity/play-billing)
- [Receive Payments via Google Play Billing with the Digital Goods API](https://developer.chrome.com/docs/android/trusted-web-activity/receive-payments-play-billing)
- [Bubblewrap #730 — Android 13 notification permission not auto-granted](https://github.com/GoogleChromeLabs/bubblewrap/issues/730)
- [Google Play closed testing: 12 testers / 14 days](https://www.testfi.app/blog/google-play-closed-testing-requirement-explained) (organization accounts exempt)

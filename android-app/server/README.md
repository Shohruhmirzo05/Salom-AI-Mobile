# Optional: Android App Links (one file, one nginx block)

**Not required.** The app is a native WebView shell — it already renders full
screen with no browser chrome and needs nothing from the server.

Publishing this file adds one thing: `https://salom-ai.uz/*` links tapped anywhere
on the device (a shared presentation, a push landing page, a Payme/Click return
URL) open **directly in the app** instead of showing an app-chooser dialog or going
to the browser. Worth doing, but at your convenience.

---

## 1. Publish `assetlinks.json`

Copy `assetlinks.json` (this directory) to the web app's public folder:

```sh
cp android-app/server/assetlinks.json \
   ../Salom-AI/web/public/.well-known/assetlinks.json
```

It must end up live at exactly:

```
https://salom-ai.uz/.well-known/assetlinks.json
```

### Fill in the real fingerprint first

The file currently contains three entries:

| Fingerprint | Purpose |
|---|---|
| `REPLACE_WITH_PLAY_APP_SIGNING_SHA256` | **Must be replaced.** Play Console → your app → **Test and release → App integrity → App signing** → copy the **SHA-256 certificate fingerprint** of the *app signing key* (not the upload key). |
| `33:D9:…:D2:D0` | The release **upload** key, for locally-built release APKs. |
| `E3:D9:…:50:EF` | The local Android debug key on this machine. Lets the debug build verify too, so you can confirm the whole flow before the first Play upload. **Safe to keep** — it only grants the ability to open your own site full-screen, and only to an app that is already signed by that exact key. Remove it if you prefer. |

Until the Play fingerprint is filled in, links open in the browser rather than the
app. Nothing else is affected.

---

## 2. Make the file fail loudly

`web/nginx.conf` currently ends every unmatched path with
`try_files $uri $uri/ $uri/index.html /index.html`. That means a missing or
misspelled `assetlinks.json` returns **`index.html` with HTTP 200**, not a 404 —
so a mistake here is completely silent. (This is verifiably the case today:
`curl https://salom-ai.uz/.well-known/assetlinks.json` currently returns HTML.)

Add this next to the existing `apple-app-site-association` block in
`Salom-AI/web/nginx.conf`:

```nginx
location = /.well-known/assetlinks.json {
  default_type application/json;
  try_files $uri =404;
  add_header Cache-Control "no-cache";
}
```

---

## 3. Verify

```sh
# Must print application/json and a JSON body — NOT text/html.
curl -sI https://salom-ai.uz/.well-known/assetlinks.json | grep -i content-type
curl -s  https://salom-ai.uz/.well-known/assetlinks.json

# Google's own checker (should report the link as verified):
open "https://developers.google.com/digital-asset-links/tools/generator"
```

On a device, after installing the app:

```sh
adb shell pm verify-app-links --re-verify com.feratech.salomai
adb shell pm get-app-links com.feratech.salomai      # expect: salom-ai.uz: verified
```

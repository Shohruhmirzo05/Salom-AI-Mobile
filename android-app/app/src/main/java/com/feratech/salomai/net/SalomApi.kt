package com.feratech.salomai.net

import android.util.Log
import com.feratech.salomai.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.BufferedReader
import java.net.HttpURLConnection
import java.net.URL

/**
 * Minimal client for the handful of backend calls the shell makes itself.
 *
 * Everything else goes through the web app as usual — this exists only for the
 * two things native code has to do on its own: exchange a Google ID token for a
 * session, and register the push device.
 *
 * Deliberately HttpURLConnection rather than a networking library: four requests
 * do not justify pulling OkHttp/Retrofit into a 1.5 MB shell.
 */
object SalomApi {

    private const val TAG = "SalomApi"
    private const val TIMEOUT_MS = 20_000

    data class Session(val accessToken: String, val refreshToken: String)

    /**
     * Exchanges a Google ID token for a Salom AI session.
     *
     * The backend accepts this unchanged: `GOOGLE_CLIENT_IDS` in
     * backend/app/config.py already contains the web client ID, and Credential
     * Manager mints tokens with that as the audience.
     */
    suspend fun verifyGoogleIdToken(idToken: String): Session? = withContext(Dispatchers.IO) {
        val body = JSONObject()
            .put("provider", "google")
            .put("id_token", idToken)
            .put("platform", "android")
        val json = post("/auth/oauth/verify", body.toString(), token = null) ?: return@withContext null
        val access = json.optString("access_token").takeIf { it.isNotEmpty() }
            ?: return@withContext null
        Session(access, json.optString("refresh_token"))
    }

    /** @return the numeric user id, used as the OneSignal external id. */
    suspend fun currentUserId(accessToken: String): Long? = withContext(Dispatchers.IO) {
        val json = get("/auth/me", accessToken) ?: return@withContext null
        json.optLong("id").takeIf { it > 0 }
    }

    /** Registers the OneSignal subscription id against the signed-in user. */
    suspend fun registerDevice(accessToken: String, subscriptionId: String): Boolean =
        withContext(Dispatchers.IO) {
            val body = JSONObject().put("token", subscriptionId).put("platform", "android")
            post("/notifications/device", body.toString(), accessToken) != null
        }

    /** Marks the user's most recent platform as Android for analytics/segmentation. */
    suspend fun reportPlatform(accessToken: String): Boolean = withContext(Dispatchers.IO) {
        post("/auth/platform", JSONObject().put("platform", "android").toString(), accessToken) != null
    }

    // ---------------------------------------------------------------- internals

    private fun get(path: String, token: String?): JSONObject? = request("GET", path, null, token)

    private fun post(path: String, body: String, token: String?): JSONObject? =
        request("POST", path, body, token)

    private fun request(method: String, path: String, body: String?, token: String?): JSONObject? {
        var conn: HttpURLConnection? = null
        return try {
            conn = (URL(BuildConfig.API_BASE + path).openConnection() as HttpURLConnection).apply {
                requestMethod = method
                connectTimeout = TIMEOUT_MS
                readTimeout = TIMEOUT_MS
                setRequestProperty("Accept", "application/json")
                token?.let { setRequestProperty("Authorization", "Bearer $it") }
                if (body != null) {
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json")
                }
            }
            body?.let { conn.outputStream.use { out -> out.write(it.toByteArray()) } }

            val code = conn.responseCode
            if (code !in 200..299) {
                // Never log the body: it can contain tokens.
                Log.w(TAG, "$method $path failed with HTTP $code")
                return null
            }
            val text = conn.inputStream.bufferedReader().use(BufferedReader::readText)
            if (text.isBlank()) JSONObject() else JSONObject(text)
        } catch (e: Exception) {
            Log.w(TAG, "$method $path failed: ${e.javaClass.simpleName}")
            null
        } finally {
            conn?.disconnect()
        }
    }
}

package com.feratech.salomai.auth

import android.content.Context
import android.util.Log
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import com.feratech.salomai.BuildConfig
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential

/**
 * Native Google Sign-In, used in place of the web OAuth redirect.
 *
 * Google refuses to serve accounts.google.com inside an embedded WebView
 * (`disallowed_useragent`), so [com.feratech.salomai.web.NavigationPolicy]
 * intercepts that navigation and this runs instead.
 *
 * The resulting ID token is accepted by the existing backend with no change:
 * Credential Manager sets `aud` to the **server** client ID passed here, which is
 * already whitelisted in backend/app/config.py `GOOGLE_CLIENT_IDS`. The Android
 * OAuth client registered in Google Cloud is only used to authenticate the app —
 * it never appears as the audience.
 */
class GoogleSignInBridge(private val context: Context) {

    sealed interface Result {
        data class Success(val idToken: String) : Result
        data object Cancelled : Result
        data class Failure(val reason: String) : Result
    }

    private val credentialManager by lazy { CredentialManager.create(context) }

    suspend fun signIn(): Result {
        // First pass: only accounts already authorised for this app, which gives a
        // one-tap experience for returning users.
        authorisedOnly(true)?.let { return it }
        // Second pass: full account picker for first-time sign-in.
        return authorisedOnly(false) ?: Result.Failure("No Google account available")
    }

    private suspend fun authorisedOnly(filter: Boolean): Result? {
        val option = GetGoogleIdOption.Builder()
            .setServerClientId(BuildConfig.GOOGLE_SERVER_CLIENT_ID)
            .setFilterByAuthorizedAccounts(filter)
            .setAutoSelectEnabled(false)
            .build()

        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()

        return try {
            val response = credentialManager.getCredential(context, request)
            val credential = response.credential
            if (credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                return Result.Failure("Unexpected credential type: ${credential.type}")
            }
            val token = GoogleIdTokenCredential.createFrom(credential.data).idToken
            if (token.isEmpty()) Result.Failure("Empty ID token") else Result.Success(token)
        } catch (e: NoCredentialException) {
            // Nothing matched this filter — let the caller try the wider query.
            null
        } catch (e: GetCredentialCancellationException) {
            Result.Cancelled
        } catch (e: GetCredentialException) {
            // The usual cause here is a missing/incorrect Android OAuth client in
            // Google Cloud Console (package name + signing SHA-1 must both match).
            Log.w(TAG, "Google sign-in failed: ${e.type} ${e.errorMessage}")
            Result.Failure(e.errorMessage?.toString() ?: e.type)
        } catch (e: Exception) {
            Log.w(TAG, "Google sign-in error", e)
            Result.Failure(e.javaClass.simpleName)
        }
    }

    private companion object {
        const val TAG = "GoogleSignIn"
    }
}

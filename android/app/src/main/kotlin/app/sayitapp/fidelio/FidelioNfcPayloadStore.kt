package app.sayitapp.fidelio

import android.content.Context

object FidelioNfcPayloadStore {
    private const val PREFS_NAME = "fidelio_nfc_payload"
    private const val KEY_PAYLOAD = "payload"
    private const val KEY_RECEIVE_MODE = "receive_mode"

    @Volatile
    private var cachedPayload: String = ""
    @Volatile
    private var receiveMode: Boolean = false

    fun setPayload(context: Context, payload: String) {
        cachedPayload = payload
        receiveMode = false
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PAYLOAD, payload)
            .putBoolean(KEY_RECEIVE_MODE, false)
            .apply()
    }

    fun getPayload(context: Context): String {
        if (cachedPayload.isNotEmpty()) {
            return cachedPayload
        }
        cachedPayload = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_PAYLOAD, "")
            .orEmpty()
        return cachedPayload
    }

    fun startReceive(context: Context) {
        receiveMode = true
        cachedPayload = ""
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PAYLOAD, "")
            .putBoolean(KEY_RECEIVE_MODE, true)
            .apply()
    }

    fun isReceiveMode(context: Context): Boolean {
        if (receiveMode) {
            return true
        }
        receiveMode = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_RECEIVE_MODE, false)
        return receiveMode
    }

    fun completeReceive(context: Context, payload: String) {
        cachedPayload = payload
        receiveMode = false
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PAYLOAD, payload)
            .putBoolean(KEY_RECEIVE_MODE, false)
            .apply()
    }
}

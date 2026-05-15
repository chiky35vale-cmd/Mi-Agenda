package com.tunombre.recordatorio

class VoiceEntryActivity : TtsFlutterActivity() {
    override val allowsLockedScreenLaunch: Boolean = true

    override fun getInitialRoute(): String = "/voice-quick-create"
}

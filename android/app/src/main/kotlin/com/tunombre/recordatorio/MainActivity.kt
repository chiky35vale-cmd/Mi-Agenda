package com.tunombre.recordatorio

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.MediaStore

class MainActivity : TtsFlutterActivity() {
    override val allowsLockedScreenLaunch: Boolean = true

    override fun getInitialRoute(): String {
        explicitRoute(intent)?.let { route ->
            return route
        }

        return if (shouldOpenVoiceQuickCreate(intent)) {
            VOICE_QUICK_CREATE_ROUTE
        } else {
            DEFAULT_ROUTE
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val route = explicitRoute(intent)
        val shouldOpenVoice = route == VOICE_QUICK_CREATE_ROUTE || shouldOpenVoiceQuickCreate(intent)
        if (!shouldOpenVoice) {
            return
        }

        getFlutterEngine()
            ?.navigationChannel
            ?.pushRoute(route ?: VOICE_QUICK_CREATE_ROUTE)
    }

    private fun shouldOpenVoiceQuickCreate(intent: Intent?): Boolean {
        val launchAction = intent?.action
        if (launchAction == MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA ||
            launchAction == MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA_SECURE ||
            launchAction == Intent.ACTION_VOICE_COMMAND ||
            launchAction == Intent.ACTION_ASSIST
        ) {
            return true
        }

        if (launchAction != Intent.ACTION_MAIN) {
            return false
        }

        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        val screenWasOff = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
            powerManager?.isInteractive == false
        } else {
            @Suppress("DEPRECATION")
            powerManager?.isScreenOn == false
        }
        if (screenWasOff) {
            return true
        }

        val keyguardManager =
            getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                ?: return false

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            keyguardManager.isDeviceLocked || keyguardManager.isKeyguardLocked
        } else {
            keyguardManager.isKeyguardLocked
        }
    }

    private fun explicitRoute(intent: Intent?): String? {
        return intent
            ?.getStringExtra(EXTRA_INITIAL_ROUTE)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
    }

    companion object {
        private const val DEFAULT_ROUTE = "/"
        const val EXTRA_INITIAL_ROUTE = "route"
        private const val VOICE_QUICK_CREATE_ROUTE = "/voice-quick-create"
    }
}

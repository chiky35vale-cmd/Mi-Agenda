package com.tunombre.recordatorio

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

class VolumeButtonAccessibilityService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private var isLongPressTriggered = false
    private var volumeUpPressed = false
    private var volumeDownPressed = false

    private val longPressRunnable = Runnable {
        if (volumeUpPressed || volumeDownPressed) {
            isLongPressTriggered = true
            launchVoiceEntry()
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()

        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
            notificationTimeout = 100
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                flags = flags or AccessibilityServiceInfo.FLAG_REQUEST_FINGERPRINT_GESTURES
            }
        }
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // No necesitamos procesar eventos de accesibilidad especificos.
    }

    override fun onInterrupt() {
        resetState()
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        // Solo interceptamos teclas de volumen
        when (event.keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP,
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                return handleVolumeKey(event)
            }
            else -> return false
        }
    }

    private fun handleVolumeKey(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN) {
            val isVolumeUp = event.keyCode == KeyEvent.KEYCODE_VOLUME_UP

            if (isVolumeUp) {
                volumeUpPressed = true
            } else {
                volumeDownPressed = true
            }

            // Si ambas teclas estan presionadas o mantenemos una pulsada, lanzamos
            if (volumeUpPressed && volumeDownPressed) {
                // Pulsacion simultanea de volumen arriba + abajo
                resetState()
                launchVoiceEntry()
                return true
            }

            // Programar deteccion de pulsacion larga (800ms)
            if (!isLongPressTriggered) {
                handler.postDelayed(longPressRunnable, LONG_PRESS_DURATION_MS)
            }

            return true
        } else if (event.action == KeyEvent.ACTION_UP) {
            // Cancelar pulsacion larga si se suelta antes de tiempo
            handler.removeCallbacks(longPressRunnable)

            val fromVolumeUp = event.keyCode == KeyEvent.KEYCODE_VOLUME_UP
            val fromVolumeDown = event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN

            // Si no se ha disparado la pulsacion larga, dejamos que el sistema procese la tecla
            if (!isLongPressTriggered) {
                if (fromVolumeUp) volumeUpPressed = false
                if (fromVolumeDown) volumeDownPressed = false
                return false
            }

            resetState()
            return true
        }

        return false
    }

    private fun launchVoiceEntry() {
        wakeUpDeviceIfNeeded()

        val intent = Intent(this, VoiceEntryActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.EXTRA_INITIAL_ROUTE, "/voice-quick-create")
        }
        startActivity(intent)
    }

    private fun wakeUpDeviceIfNeeded() {
        try {
            val powerManager = getSystemService(POWER_SERVICE) as? PowerManager ?: return
            val isInteractive = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                powerManager.isInteractive
            } else {
                @Suppress("DEPRECATION")
                powerManager.isScreenOn
            }

            if (!isInteractive) {
                val wakeLock = powerManager.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                            PowerManager.ACQUIRE_CAUSES_WAKEUP or
                            PowerManager.ON_AFTER_RELEASE,
                    "Recordatorio:VoiceWakeLock"
                )
                wakeLock.acquire(1500L)
            }
        } catch (_: Exception) {
            // Si no podemos despertar la pantalla, igualmente intentamos lanzar la actividad.
        }
    }

    private fun resetState() {
        handler.removeCallbacks(longPressRunnable)
        volumeUpPressed = false
        volumeDownPressed = false
        isLongPressTriggered = false
    }

    override fun onDestroy() {
        resetState()
        super.onDestroy()
    }

    companion object {
        private const val LONG_PRESS_DURATION_MS = 800L
    }
}

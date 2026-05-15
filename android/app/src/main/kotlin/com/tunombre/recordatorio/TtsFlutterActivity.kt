package com.tunombre.recordatorio

import android.os.Build
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

open class TtsFlutterActivity : FlutterActivity() {
    private var textToSpeech: TextToSpeech? = null
    private var isTtsReady = false
    private var pendingSpeech: PendingSpeech? = null
    protected open val allowsLockedScreenLaunch: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (allowsLockedScreenLaunch) {
            enableLockedScreenLaunch()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VOICE_CONFIRMATION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "speakConfirmation" -> {
                    val text = call.argument<String>("text")?.trim()
                    if (text.isNullOrEmpty()) {
                        result.error(
                            "empty_text",
                            "No se ha recibido texto para la confirmacion por voz.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    speakConfirmation(text, result)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        super.onDestroy()
    }

    private fun enableLockedScreenLaunch() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
    }

    private fun speakConfirmation(text: String, result: MethodChannel.Result) {
        pendingSpeech = PendingSpeech(text, result)

        val existingTts = textToSpeech
        if (existingTts == null) {
            textToSpeech = TextToSpeech(this) { status ->
                runOnUiThread {
                    if (status != TextToSpeech.SUCCESS) {
                        failPendingSpeech("tts_init_error", "No se pudo iniciar la voz del sistema.")
                        return@runOnUiThread
                    }

                    val configuredTts = textToSpeech ?: run {
                        failPendingSpeech("tts_missing", "La voz del sistema no esta disponible.")
                        return@runOnUiThread
                    }

                    val languageStatus = configuredTts.setLanguage(Locale("es", "ES"))
                    if (languageStatus == TextToSpeech.LANG_MISSING_DATA ||
                        languageStatus == TextToSpeech.LANG_NOT_SUPPORTED
                    ) {
                        failPendingSpeech(
                            "tts_language_error",
                            "La voz en espanol no esta disponible en este dispositivo.",
                        )
                        return@runOnUiThread
                    }

                    configuredTts.setSpeechRate(0.95f)
                    configuredTts.setPitch(1.0f)
                    isTtsReady = true
                    flushPendingSpeech()
                }
            }
            return
        }

        if (isTtsReady) {
            flushPendingSpeech()
        } else {
            existingTts.stop()
        }
    }

    private fun flushPendingSpeech() {
        val currentSpeech = pendingSpeech ?: return
        val activeTts = textToSpeech ?: run {
            failPendingSpeech("tts_missing", "La voz del sistema no esta disponible.")
            return
        }

        val utteranceId = "voice_confirmation_${System.currentTimeMillis()}"
        activeTts.setOnUtteranceProgressListener(
            object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) = Unit

                override fun onDone(doneUtteranceId: String?) {
                    if (doneUtteranceId != utteranceId) {
                        return
                    }

                    runOnUiThread {
                        if (pendingSpeech === currentSpeech) {
                            pendingSpeech = null
                        }
                        currentSpeech.result.success(true)
                    }
                }

                override fun onError(errorUtteranceId: String?) {
                    if (errorUtteranceId != utteranceId) {
                        return
                    }

                    runOnUiThread {
                        if (pendingSpeech === currentSpeech) {
                            pendingSpeech = null
                        }
                        currentSpeech.result.error(
                            "tts_speak_error",
                            "No se pudo reproducir la confirmacion por voz.",
                            null,
                        )
                    }
                }
            },
        )

        val speakStatus = activeTts.speak(
            currentSpeech.text,
            TextToSpeech.QUEUE_FLUSH,
            null,
            utteranceId,
        )

        if (speakStatus == TextToSpeech.ERROR) {
            failPendingSpeech("tts_speak_error", "No se pudo reproducir la confirmacion por voz.")
        }
    }

    private fun failPendingSpeech(code: String, message: String) {
        val currentSpeech = pendingSpeech ?: return
        pendingSpeech = null
        currentSpeech.result.error(code, message, null)
    }

    private data class PendingSpeech(
        val text: String,
        val result: MethodChannel.Result,
    )

    companion object {
        private const val VOICE_CONFIRMATION_CHANNEL =
            "com.tunombre.recordatorio/voice_confirmation"
    }
}

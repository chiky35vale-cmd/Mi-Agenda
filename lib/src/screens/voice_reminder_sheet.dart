import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceReminderSheet extends StatefulWidget {
  const VoiceReminderSheet({
    super.key,
    this.autoStartListening = false,
    this.autoCreateOnResult = false,
  });

  final bool autoStartListening;
  final bool autoCreateOnResult;

  @override
  State<VoiceReminderSheet> createState() => _VoiceReminderSheetState();
}

class _VoiceReminderSheetState extends State<VoiceReminderSheet> {
  final SpeechToText _speech = SpeechToText();

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isInitializing = true;
  String _recognizedText = '';
  String? _errorMessage;
  String? _localeId;
  bool _hasAutoStarted = false;
  bool _hasEverListened = false;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Crear por voz',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.autoCreateOnResult
                  ? 'Habla cuando el microfono se active. En cuanto termine de escucharte, el recordatorio se guardara solo.'
                  : 'Di algo como: "Recordarme llamar al dentista manana a las 9 cada semana" o "Comprar pan hoy a las 18". Cuando pulses crear, el recordatorio se guardara directamente.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _isListening
                        ? 'Escuchando...'
                        : _isInitializing
                        ? 'Preparando microfono...'
                        : 'Texto detectado',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _recognizedText.isEmpty
                        ? widget.autoCreateOnResult
                              ? 'Voy a activar el microfono automaticamente. Habla con normalidad cuando empiece a escuchar.'
                              : 'Pulsa el microfono y dicta el recordatorio.'
                        : _recognizedText,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                  if (_errorMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isListening
                        ? _stopListening
                        : _speechAvailable && !_isInitializing
                        ? _startListening
                        : null,
                    icon: Icon(
                      _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    ),
                    label: Text(
                      _isListening
                          ? 'Detener'
                          : widget.autoCreateOnResult
                          ? 'Escuchar otra vez'
                          : 'Escuchar',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _recognizedText.trim().isEmpty
                        ? null
                        : () =>
                              Navigator.of(context).pop(_recognizedText.trim()),
                    child: const Text('Crear ahora'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeSpeech() async {
    final available = await _speech.initialize(
      onStatus: _handleSpeechStatus,
      onError: (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _errorMessage = 'No se pudo usar el microfono: ${error.errorMsg}.';
          _isListening = false;
        });
      },
    );

    String? localeId;
    if (available) {
      final locales = await _speech.locales();
      LocaleName? spanishLocale;
      for (final locale in locales) {
        if (locale.localeId.toLowerCase().startsWith('es')) {
          spanishLocale = locale;
          break;
        }
      }
      localeId =
          spanishLocale?.localeId ??
          (locales.isNotEmpty ? locales.first.localeId : 'es_ES');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _speechAvailable = available;
      _localeId = localeId;
      _isInitializing = false;
      if (!available) {
        _errorMessage =
            'El reconocimiento de voz no esta disponible en este dispositivo.';
      }
    });

    _scheduleAutoStart();
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _recognizedText = '';
    });

    _hasEverListened = true;
    final didStart = await _speech.listen(
      onResult: (result) {
        if (!mounted) {
          return;
        }
        setState(() {
          _recognizedText = result.recognizedWords;
        });
        if (widget.autoCreateOnResult && result.finalResult) {
          _submitRecognizedText();
        }
      },
      localeId: _localeId,
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 4),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isListening = didStart;
      if (!didStart && _errorMessage == null) {
        _errorMessage = 'No se pudo activar el microfono. Vuelve a intentarlo.';
      }
    });
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (!mounted) {
      return;
    }

    setState(() {
      _isListening = false;
    });
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) {
      return;
    }

    final isListening = status == SpeechToText.listeningStatus;
    setState(() {
      _isListening = isListening;
      if (widget.autoCreateOnResult &&
          !isListening &&
          _hasEverListened &&
          _recognizedText.trim().isEmpty) {
        _errorMessage =
            'No he detectado ninguna frase. Pulsa "Escuchar otra vez" y vuelve a hablar.';
      }
    });

    if (!isListening) {
      _submitRecognizedText();
    }
  }

  void _scheduleAutoStart() {
    if (!widget.autoStartListening ||
        _hasAutoStarted ||
        _isInitializing ||
        !_speechAvailable) {
      return;
    }

    _hasAutoStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _startListening();
    });
  }

  void _submitRecognizedText() {
    if (!widget.autoCreateOnResult || _hasSubmitted || !mounted) {
      return;
    }

    final transcript = _recognizedText.trim();
    if (transcript.isEmpty) {
      return;
    }

    _hasSubmitted = true;
    Navigator.of(context).pop(transcript);
  }
}

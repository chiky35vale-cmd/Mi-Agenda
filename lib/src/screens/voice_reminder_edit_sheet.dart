import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/reminder.dart';
import '../utils/reminder_date_formatters.dart';

class VoiceReminderEditSheet extends StatefulWidget {
  const VoiceReminderEditSheet({super.key, required this.reminders});

  final List<Reminder> reminders;

  @override
  State<VoiceReminderEditSheet> createState() => _VoiceReminderEditSheetState();
}

class _VoiceReminderEditSheetState extends State<VoiceReminderEditSheet> {
  final SpeechToText _speech = SpeechToText();

  bool _speechAvailable = false;
  bool _isInitializing = true;
  bool _isListening = false;
  bool _hasAutoStarted = false;
  bool _hasEverListened = false;
  bool _hasSubmitted = false;
  String _recognizedText = '';
  String? _localeId;
  String? _errorMessage;

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
    final previewCount = widget.reminders.length > 5
        ? 5
        : widget.reminders.length;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Editar por voz',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Usa el numero de la lista. Por ejemplo: "editar recordatorio 2", "editar recordatorio 2 a las 12 y 35" o "editar 1 titulo comprar pan".',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Recordatorios numerados',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var index = 0; index < previewCount; index += 1)
                    _VoiceEditReminderPreview(
                      number: index + 1,
                      reminder: widget.reminders[index],
                    ),
                  if (widget.reminders.length > previewCount) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      'Y ${widget.reminders.length - previewCount} mas en la lista.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isListening
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _isListening
                        ? 'Escuchando...'
                        : _isInitializing
                        ? 'Preparando microfono...'
                        : 'Comando detectado',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _recognizedText.isEmpty
                        ? 'Voy a activar el microfono automaticamente. Di el numero y el cambio que quieres hacer.'
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
            FilledButton.icon(
              onPressed: _isListening
                  ? _stopListening
                  : _speechAvailable && !_isInitializing
                  ? _startListening
                  : null,
              icon: Icon(_isListening ? Icons.stop_rounded : Icons.mic_rounded),
              label: Text(_isListening ? 'Detener' : 'Escuchar otra vez'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
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
                        : _submitRecognizedText,
                    child: const Text('Aplicar'),
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

  void _scheduleAutoStart() {
    if (_hasAutoStarted || _isInitializing || !_speechAvailable || !mounted) {
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

  Future<void> _startListening() async {
    if (!_speechAvailable || _isInitializing) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _recognizedText = '';
      _hasSubmitted = false;
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
        if (result.finalResult) {
          _submitRecognizedText();
        }
      },
      localeId: _localeId,
      listenFor: const Duration(seconds: 24),
      pauseFor: const Duration(seconds: 5),
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
      ),
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
    _submitRecognizedText();
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) {
      return;
    }

    final isListening = status == SpeechToText.listeningStatus;
    setState(() {
      _isListening = isListening;
      if (!isListening && _hasEverListened && _recognizedText.trim().isEmpty) {
        _errorMessage =
            'No he detectado ningun comando. Pulsa "Escuchar otra vez" y vuelve a hablar.';
      }
    });

    if (!isListening) {
      _submitRecognizedText();
    }
  }

  void _submitRecognizedText() {
    if (_hasSubmitted || !mounted) {
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

class _VoiceEditReminderPreview extends StatelessWidget {
  const _VoiceEditReminderPreview({
    required this.number,
    required this.reminder,
  });

  final int number;
  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$number.',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${reminder.title} - ${formatReminderDateTime(reminder.scheduledAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

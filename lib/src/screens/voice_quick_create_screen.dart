import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../services/voice_confirmation_service.dart';
import '../utils/voice_dictation.dart';
import '../utils/voice_reminder_creation.dart';
import '../utils/voice_reminder_parser.dart';
import '../utils/voice_text_polisher.dart';

enum _VoiceQuickCreateStep { reminder, schedule }

class VoiceQuickCreateScreen extends StatefulWidget {
  const VoiceQuickCreateScreen({super.key});

  @override
  State<VoiceQuickCreateScreen> createState() => _VoiceQuickCreateScreenState();
}

class _VoiceQuickCreateScreenState extends State<VoiceQuickCreateScreen> {
  final SpeechToText _speech = SpeechToText();

  _VoiceQuickCreateStep _step = _VoiceQuickCreateStep.reminder;
  bool _speechAvailable = false;
  bool _isInitializing = true;
  bool _isListening = false;
  bool _isSaving = false;
  bool _isConfirming = false;
  bool _isPromptingScheduleQuestion = false;
  bool _hasAutoStarted = false;
  bool _hasSubmitted = false;
  bool _restartScheduled = false;
  bool _shouldSubmitWhenStopped = false;
  bool _manualStopRequested = false;
  String _committedTranscript = '';
  String _sessionTranscript = '';
  String _pendingReminderTranscript = '';
  String _pendingReminderTitle = '';
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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                    size: 52,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _headlineText,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _supportingText,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                  textAlign: TextAlign.center,
                ),
                if (_step == _VoiceQuickCreateStep.schedule &&
                    _pendingReminderTitle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Recordatorio',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _pendingReminderTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
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
                  child: Text(
                    _displayTranscript.isEmpty
                        ? _placeholderTranscript
                        : _displayTranscript,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                if (_isSaving ||
                    _isInitializing ||
                    _isConfirming ||
                    _isPromptingScheduleQuestion)
                  const CircularProgressIndicator()
                else
                  FilledButton.icon(
                    onPressed: _isListening
                        ? _stopListening
                        : _restartListening,
                    icon: Icon(
                      _isListening
                          ? Icons.stop_rounded
                          : _step == _VoiceQuickCreateStep.schedule
                          ? Icons.schedule_rounded
                          : Icons.refresh_rounded,
                    ),
                    label: Text(_primaryActionLabel),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    if (_step == _VoiceQuickCreateStep.schedule)
                      TextButton(
                        onPressed: _isListening ? null : _restartReminderFlow,
                        child: const Text('Cambiar recordatorio'),
                      ),
                    TextButton(
                      onPressed: _openReminderList,
                      child: const Text('Abrir lista'),
                    ),
                    TextButton(
                      onPressed: _closeFlow,
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _displayTranscript =>
      mergeVoiceDictationTranscript(_committedTranscript, _sessionTranscript);

  String get _headlineText {
    if (_isSaving) {
      return 'Guardando...';
    }
    if (_isConfirming) {
      return 'Confirmando por voz...';
    }
    if (_isPromptingScheduleQuestion) {
      return '\u00bfFecha y hora?';
    }
    if (_isListening) {
      return _step == _VoiceQuickCreateStep.reminder
          ? 'Dime recordatorio, tarea, compra o nota'
          : '\u00bfFecha y hora?';
    }
    if (_isInitializing) {
      return 'Preparando microfono...';
    }
    if (_errorMessage != null) {
      return 'No he podido guardarlo';
    }
    return _step == _VoiceQuickCreateStep.reminder
        ? 'Listo para crear por voz'
        : '\u00bfFecha y hora?';
  }

  String get _supportingText {
    if (_isSaving) {
      return 'Estoy interpretando lo que me has pedido para guardarlo.';
    }
    if (_isConfirming) {
      return 'Ya lo he guardado. Voy a confirmartelo en voz antes de cerrar.';
    }
    if (_isPromptingScheduleQuestion) {
      return 'Ya tengo el recordatorio. Ahora necesito saber cuando quieres que te avise.';
    }
    if (_isListening) {
      return _step == _VoiceQuickCreateStep.reminder
          ? 'Di "comprar" para una compra, "tarea" para guardar sin fecha, "nota" para una nota, o un recordatorio y termina con "ok".'
          : 'Responde con fecha y hora o minutos. Por ejemplo: "4 y 53 de la tarde ok".';
    }
    if (_isInitializing) {
      return 'En unos instantes activare la escucha automaticamente.';
    }
    if (_errorMessage != null) {
      return _step == _VoiceQuickCreateStep.reminder
          ? 'Vuelve a decirlo y termina con "ok".'
          : 'Necesito una fecha y una hora para guardarlo. Termina con "ok".';
    }
    return _step == _VoiceQuickCreateStep.reminder
        ? 'Di "comprar leche ok" para la compra, "tarea llamar a Juan ok", "nota clave del wifi ok", o un recordatorio para que te pregunte fecha y hora.'
        : 'Ahora dime fecha y hora y termina con "ok" para guardarlo.';
  }

  String get _placeholderTranscript {
    return _step == _VoiceQuickCreateStep.reminder
        ? 'Ejemplo: nota clave del wifi ok.'
        : 'Ejemplo: 4 y 53 de la tarde ok.';
  }

  String get _primaryActionLabel {
    if (_isListening) {
      return 'Detener';
    }
    return _step == _VoiceQuickCreateStep.schedule
        ? 'Repetir fecha y hora'
        : 'Escuchar otra vez';
  }

  Future<void> _initializeSpeech() async {
    final available = await _speech.initialize(
      onStatus: _handleSpeechStatus,
      onError: (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isListening = false;
          _errorMessage = 'No se pudo usar el microfono: ${error.errorMsg}.';
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
    if (_hasAutoStarted || !_speechAvailable || _isInitializing) {
      return;
    }

    _hasAutoStarted = true;
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || _isListening || _isSaving || _isConfirming) {
        return;
      }
      _startListening(resetTranscript: true);
    });
  }

  void _restartListening() {
    if (_step == _VoiceQuickCreateStep.reminder) {
      _restartReminderFlow();
    }
    _startListening(resetTranscript: true);
  }

  void _restartReminderFlow() {
    if (!mounted) {
      return;
    }

    setState(() {
      _step = _VoiceQuickCreateStep.reminder;
      _pendingReminderTranscript = '';
      _pendingReminderTitle = '';
      _committedTranscript = '';
      _sessionTranscript = '';
      _errorMessage = null;
      _hasSubmitted = false;
      _manualStopRequested = false;
      _shouldSubmitWhenStopped = false;
    });
  }

  Future<void> _startListening({required bool resetTranscript}) async {
    if (!_speechAvailable ||
        _isSaving ||
        _isConfirming ||
        _isPromptingScheduleQuestion) {
      return;
    }

    setState(() {
      if (resetTranscript) {
        _committedTranscript = '';
      }
      _sessionTranscript = '';
      _errorMessage = null;
      _hasSubmitted = false;
      _manualStopRequested = false;
      _shouldSubmitWhenStopped = false;
    });

    final didStart = await _speech.listen(
      onResult: (result) {
        if (!mounted) {
          return;
        }

        setState(() {
          _sessionTranscript = result.recognizedWords;
        });

        if (hasVoiceDictationTerminator(_displayTranscript)) {
          _requestSubmissionAfterStop();
        }
      },
      localeId: _localeId,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 8),
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
        _errorMessage =
            'No se pudo activar la escucha automaticamente. Intentalo otra vez.';
      }
    });
  }

  Future<void> _stopListening() async {
    _manualStopRequested = true;
    _shouldSubmitWhenStopped = false;
    await _speech.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _isListening = false;
    });
  }

  void _requestSubmissionAfterStop() {
    if (_shouldSubmitWhenStopped ||
        _hasSubmitted ||
        _isSaving ||
        _isConfirming) {
      return;
    }

    _shouldSubmitWhenStopped = true;
    _speech.stop();
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) {
      return;
    }

    final isListening = status == SpeechToText.listeningStatus;
    final shouldSubmit = _shouldSubmitWhenStopped;
    final manualStopRequested = _manualStopRequested;
    final combinedBeforeCommit = _displayTranscript;

    setState(() {
      _isListening = isListening;
      if (!isListening) {
        _committedTranscript = mergeVoiceDictationTranscript(
          _committedTranscript,
          _sessionTranscript,
        );
        _sessionTranscript = '';
        _shouldSubmitWhenStopped = false;
        _manualStopRequested = false;
      }
    });

    if (isListening) {
      return;
    }

    final combinedTranscript = _displayTranscript;
    if (shouldSubmit || hasVoiceDictationTerminator(combinedTranscript)) {
      if (_step == _VoiceQuickCreateStep.reminder) {
        _advanceToScheduleQuestion();
      } else {
        _tryCreateReminder();
      }
      return;
    }

    if (manualStopRequested) {
      if (combinedBeforeCommit.trim().isNotEmpty) {
        setState(() {
          _errorMessage = _step == _VoiceQuickCreateStep.reminder
              ? 'Todavia no he guardado nada. Dime el recordatorio y termina con "ok".'
              : 'Todavia no he guardado nada. Dime fecha y hora y termina con "ok".';
        });
      }
      return;
    }

    _scheduleListeningResume();
  }

  void _scheduleListeningResume() {
    if (_restartScheduled ||
        _isSaving ||
        _isConfirming ||
        _hasSubmitted ||
        _isPromptingScheduleQuestion) {
      return;
    }

    _restartScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      _restartScheduled = false;
      if (!mounted ||
          _isListening ||
          _isSaving ||
          _isConfirming ||
          _hasSubmitted ||
          _isPromptingScheduleQuestion) {
        return;
      }
      _startListening(resetTranscript: false);
    });
  }

  Future<void> _advanceToScheduleQuestion() async {
    final reminderTranscript = polishVoiceTranscriptText(
      sanitizeVoiceDictationTranscript(_displayTranscript),
    );

    if (_hasSubmitted || _isSaving || _isConfirming || !mounted) {
      return;
    }

    if (reminderTranscript.isEmpty) {
      setState(() {
        _errorMessage =
            'No he detectado que quieres recordar. Dilo otra vez y termina con "ok".';
      });
      return;
    }

    if (isVoiceShoppingListCommand(reminderTranscript)) {
      await _tryCreateShoppingListItem(reminderTranscript);
      return;
    }

    if (isVoiceNoteCommand(reminderTranscript)) {
      await _tryCreateNote(reminderTranscript);
      return;
    }

    if (isVoiceTaskCommand(reminderTranscript)) {
      await _tryCreateTask(reminderTranscript);
      return;
    }

    final reminderTitle = extractVoiceReminderTitle(reminderTranscript);
    if (reminderTitle.isEmpty) {
      setState(() {
        _errorMessage =
            'No he detectado que quieres recordar. Dilo otra vez y termina con "ok".';
      });
      return;
    }

    _hasSubmitted = true;
    setState(() {
      _isPromptingScheduleQuestion = true;
      _errorMessage = null;
      _pendingReminderTranscript = reminderTranscript;
      _pendingReminderTitle = reminderTitle;
      _step = _VoiceQuickCreateStep.schedule;
      _committedTranscript = '';
      _sessionTranscript = '';
    });

    await VoiceConfirmationService.askForDateAndTime();
    if (!mounted) {
      return;
    }

    setState(() {
      _isPromptingScheduleQuestion = false;
      _hasSubmitted = false;
    });

    await _startListening(resetTranscript: true);
  }

  Future<void> _tryCreateTask(String taskTranscript) async {
    if (_hasSubmitted || _isSaving || !mounted) {
      return;
    }

    final taskTitle = extractVoiceTaskTitle(taskTranscript);
    if (taskTitle.isEmpty) {
      setState(() {
        _errorMessage =
            'No he detectado la tarea. Di algo como "tarea comprar pan ok".';
      });
      return;
    }

    _hasSubmitted = true;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _committedTranscript = taskTranscript;
      _sessionTranscript = '';
    });

    try {
      final createdTitle = await createTaskFromVoiceTranscript(
        context,
        taskTranscript,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _isConfirming = true;
      });
      await VoiceConfirmationService.speakTaskCreated(createdTitle);
      if (!mounted) {
        return;
      }
      await _closeFlow();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _isConfirming = false;
        _hasSubmitted = false;
        _errorMessage =
            'He escuchado la tarea pero no he podido guardarla. Intentalo otra vez y termina con "ok".';
      });
    }
  }

  Future<void> _tryCreateShoppingListItem(String shoppingTranscript) async {
    if (_hasSubmitted || _isSaving || !mounted) {
      return;
    }

    final itemTitle = extractVoiceShoppingListTitle(shoppingTranscript);
    if (itemTitle.isEmpty) {
      setState(() {
        _errorMessage =
            'No he detectado que quieres comprar. Di algo como "comprar leche ok".';
      });
      return;
    }

    _hasSubmitted = true;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _committedTranscript = shoppingTranscript;
      _sessionTranscript = '';
    });

    try {
      final createdTitle = await createShoppingListItemFromVoiceTranscript(
        context,
        shoppingTranscript,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _isConfirming = true;
      });
      await VoiceConfirmationService.speakShoppingListItemCreated(createdTitle);
      if (!mounted) {
        return;
      }
      await _closeFlow();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _isConfirming = false;
        _hasSubmitted = false;
        _errorMessage =
            'He escuchado la compra pero no he podido guardarla. Intentalo otra vez y termina con "ok".';
      });
    }
  }

  Future<void> _tryCreateNote(String noteTranscript) async {
    if (_hasSubmitted || _isSaving || !mounted) {
      return;
    }

    final noteTitle = extractVoiceNoteTitle(noteTranscript);
    if (noteTitle.isEmpty) {
      setState(() {
        _errorMessage =
            'No he detectado la nota. Di algo como "nota llamar a Juan ok".';
      });
      return;
    }

    _hasSubmitted = true;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _committedTranscript = noteTranscript;
      _sessionTranscript = '';
    });

    try {
      final createdTitle = await createNoteFromVoiceTranscript(
        context,
        noteTranscript,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _isConfirming = true;
      });
      await VoiceConfirmationService.speakNoteCreated(createdTitle);
      if (!mounted) {
        return;
      }
      await _closeFlow();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _isConfirming = false;
        _hasSubmitted = false;
        _errorMessage =
            'He escuchado la nota pero no he podido guardarla. Intentalo otra vez y termina con "ok".';
      });
    }
  }

  Future<void> _tryCreateReminder() async {
    final scheduleTranscript = polishVoiceTranscriptText(
      sanitizeVoiceDictationTranscript(_displayTranscript),
    );
    if (_hasSubmitted || _isSaving || !mounted) {
      return;
    }

    if (scheduleTranscript.isEmpty) {
      setState(() {
        _errorMessage =
            'No he detectado fecha y hora. Dilo otra vez y termina con "ok".';
      });
      return;
    }

    if (!hasVoiceReminderCompleteSchedule(scheduleTranscript)) {
      setState(() {
        _errorMessage =
            'Necesito una fecha, una hora o minutos. Por ejemplo: "4 y 53 de la tarde ok".';
      });
      return;
    }

    _hasSubmitted = true;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _committedTranscript = scheduleTranscript;
      _sessionTranscript = '';
    });

    try {
      final createdTitle = await createReminderFromVoicePrompts(
        context,
        _pendingReminderTranscript,
        scheduleTranscript,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _isConfirming = true;
      });
      await VoiceConfirmationService.speakReminderCreated(createdTitle);
      if (!mounted) {
        return;
      }
      await _closeFlow();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _isConfirming = false;
        _hasSubmitted = false;
        _errorMessage =
            'He escuchado la fecha y la hora pero no he podido guardarlo. Intentalo otra vez y termina con "ok".';
      });
    }
  }

  Future<void> _closeFlow() async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(true);
      return;
    }
    await SystemNavigator.pop();
  }

  void _openReminderList() {
    if (!mounted) {
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed('/list');
  }
}

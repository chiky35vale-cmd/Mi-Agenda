import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/reminder_controller.dart';
import '../models/reminder_draft.dart';
import '../models/reminder.dart';
import '../utils/reminder_date_formatters.dart';

const List<int> _minuteAdvanceOptions = <int>[5, 10, 15, 30, 45];
const List<int> _hourAdvanceOptions = <int>[60, 120, 180, 360, 720, 1440];
const int _customAdvanceMinutesSentinel = -1;

class ReminderFormScreen extends StatefulWidget {
  const ReminderFormScreen({super.key, this.reminder, this.draft});

  final Reminder? reminder;
  final ReminderDraft? draft;

  bool get isEditing => reminder != null;

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late DateTime _selectedDateTime;
  late int _advanceMinutes;
  late ReminderRepeatInterval _repeatInterval;
  late ReminderRepeatSettings _repeatSettings;
  late final String? _voiceTranscript;

  bool _showDateError = false;
  bool _isSaving = false;
  late bool _isTaskMode;
  late bool _isShoppingListMode;
  late bool _isNoteMode;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    final initialKind =
        widget.reminder?.kind ?? draft?.kind ?? ReminderKind.reminder;
    final initialHasSchedule =
        widget.reminder?.hasSchedule ??
        draft?.hasSchedule ??
        initialKind == ReminderKind.reminder;
    _titleController = TextEditingController(
      text: widget.reminder?.title ?? draft?.title ?? '',
    );
    _selectedDateTime =
        widget.reminder?.scheduledAt ??
        draft?.scheduledAt ??
        _suggestedDateTime();
    _repeatInterval =
        widget.reminder?.repeatInterval ??
        draft?.repeatInterval ??
        ReminderRepeatInterval.none;
    _repeatSettings =
        widget.reminder?.repeatSettings ??
        draft?.repeatSettings ??
        const ReminderRepeatSettings();
    _isShoppingListMode =
        widget.reminder?.isShoppingListItem ??
        draft?.kind == ReminderKind.shoppingList;
    _isNoteMode = widget.reminder?.isNote ?? draft?.kind == ReminderKind.note;
    _isTaskMode =
        widget.reminder?.isTask ??
        (draft?.kind == ReminderKind.task ||
            (draft?.hasSchedule == false &&
                !_isShoppingListMode &&
                !_isNoteMode));
    _advanceMinutes =
        widget.reminder?.advanceReminderMinutes ??
        draft?.advanceReminderMinutes ??
        defaultAdvanceReminderMinutesForKind(
          kind: initialKind,
          hasSchedule: initialHasSchedule,
        );
    _voiceTranscript = draft?.transcript;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateError = _showDateError ? _validateDateTime() : null;
    final voiceTranscript = _voiceTranscript;
    final showIntroCard = !widget.isEditing;
    final topSectionSpacing =
        showIntroCard ||
            (voiceTranscript != null && voiceTranscript.trim().isNotEmpty)
        ? 20.0
        : 8.0;

    return Scaffold(
      appBar: AppBar(title: Text(_screenTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              widget.isEditing ? 10 : 16,
              20,
              24,
            ),
            children: <Widget>[
              if (showIntroCard)
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _introTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _introSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              if (voiceTranscript != null &&
                  voiceTranscript.trim().isNotEmpty) ...<Widget>[
                if (showIntroCard) const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Orden de voz detectada',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        voiceTranscript,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: topSectionSpacing),
              _KindSelector(
                selectedKind: _selectedKind,
                onChanged: _setSelectedKind,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _titleController,
                autofocus: !widget.isEditing,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: widget.isEditing ? 3 : 2,
                maxLines: 5,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  labelText: 'Titulo',
                  hintText: 'Ej. Llamar al dentista',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (value) {
                  final normalized = value?.trim() ?? '';
                  if (normalized.isEmpty) {
                    return 'Escribe un titulo para el recordatorio.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              if (!_isUnscheduledMode) ...<Widget>[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.calendar_month_rounded),
                        title: const Text('Fecha'),
                        subtitle: Text(formatReminderDate(_selectedDateTime)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _pickDate,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.schedule_rounded),
                        title: const Text('Hora'),
                        subtitle: Text(formatReminderTime(_selectedDateTime)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _pickTime,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Avisar antes'),
                    subtitle: Text(_formattedAdvanceLabel),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _pickAdvanceReminder,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${describeAdvanceReminder(_advanceMinutes)} Aviso previsto para ${formatReminderDateTime(_selectedDateTime.subtract(advanceReminderDuration(_advanceMinutes)))}.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.repeat_rounded),
                    title: const Text('Repetir'),
                    subtitle: Text(
                      describeRepeatReminder(
                        _repeatInterval,
                        repeatSettings: _repeatSettings,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _pickRepeatInterval,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    describeRepeatReminder(
                      _repeatInterval,
                      repeatSettings: _repeatSettings,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    _isShoppingListMode
                        ? 'Este producto no generara alarma. Quedara en Lista de la Compra hasta que lo marques como comprado.'
                        : _isNoteMode
                        ? 'Esta nota no generara alarma. Quedara guardada en la pestana Notas hasta que la archives.'
                        : 'Esta tarea no generara alarma. La veras cada dia en la lista de tareas pendientes hasta que la completes.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                ),
              if (dateError != null) ...<Widget>[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    dateError,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(
                        widget.isEditing
                            ? 'Guardar cambios'
                            : _isTaskMode
                            ? 'Crear tarea'
                            : _isShoppingListMode
                            ? 'Anotar compra'
                            : _isNoteMode
                            ? 'Guardar nota'
                            : 'Crear recordatorio',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        _selectedDateTime.hour,
        _selectedDateTime.minute,
      );
      _showDateError = false;
    });
  }

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );

    if (pickedTime == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDateTime = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      _showDateError = false;
    });
  }

  Future<void> _pickAdvanceReminder() async {
    final selectedMinutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Avisar antes',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Elige una opcion rapida o pulsa en editar para poner tus propios minutos.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 18),
                _AdvanceOptionTile(
                  label: 'A la hora exacta',
                  isSelected: _advanceMinutes == 0,
                  onTap: () => Navigator.of(context).pop(0),
                ),
                const SizedBox(height: 18),
                _AdvanceSection(
                  title: 'Minutos',
                  options: _minuteAdvanceOptions,
                  selectedMinutes: _advanceMinutes,
                ),
                const SizedBox(height: 18),
                _AdvanceSection(
                  title: 'Horas',
                  options: _hourAdvanceOptions,
                  selectedMinutes: _advanceMinutes,
                ),
                const SizedBox(height: 18),
                _AdvanceOptionTile(
                  label: 'Editar minutos',
                  subtitle: 'Escribe un valor personalizado',
                  icon: Icons.edit_rounded,
                  isSelected: !_isPresetAdvanceOption(_advanceMinutes),
                  onTap: () =>
                      Navigator.of(context).pop(_customAdvanceMinutesSentinel),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selectedMinutes == null) {
      return;
    }

    if (selectedMinutes == _customAdvanceMinutesSentinel) {
      final customMinutes = await _showCustomAdvanceDialog();
      if (!mounted || customMinutes == null) {
        return;
      }
      setState(() {
        _advanceMinutes = customMinutes;
        _showDateError = false;
      });
      return;
    }

    setState(() {
      _advanceMinutes = selectedMinutes;
      _showDateError = false;
    });
  }

  Future<void> _save() async {
    final formIsValid = _formKey.currentState?.validate() ?? false;
    final dateError = _isUnscheduledMode ? null : _validateDateTime();

    setState(() {
      _showDateError = true;
    });

    if (!formIsValid || dateError != null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final controller = context.read<ReminderController>();
      if (widget.reminder == null) {
        if (_isShoppingListMode) {
          await controller.createShoppingListItem(title: _titleController.text);
        } else if (_isNoteMode) {
          await controller.createNote(title: _titleController.text);
        } else if (_isTaskMode) {
          await controller.createTask(title: _titleController.text);
        } else {
          await controller.createReminder(
            title: _titleController.text,
            scheduledAt: _selectedDateTime,
            advanceReminderMinutes: _advanceMinutes,
            repeatInterval: _repeatInterval,
            repeatSettings: _repeatSettings,
          );
        }
      } else {
        await controller.updateReminder(
          widget.reminder!,
          title: _titleController.text,
          scheduledAt: _selectedDateTime,
          advanceReminderMinutes: _isUnscheduledMode ? 0 : _advanceMinutes,
          repeatInterval: _isUnscheduledMode
              ? ReminderRepeatInterval.none
              : _repeatInterval,
          repeatSettings: _isUnscheduledMode
              ? const ReminderRepeatSettings()
              : _repeatSettings,
          kind: _isShoppingListMode
              ? ReminderKind.shoppingList
              : _isNoteMode
              ? ReminderKind.note
              : _isTaskMode
              ? ReminderKind.task
              : ReminderKind.reminder,
          hasSchedule: !_isUnscheduledMode,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'No se pudo actualizar el recordatorio.'
                : 'No se pudo guardar el recordatorio.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _validateDateTime() {
    final notificationAt = _selectedDateTime.subtract(
      advanceReminderDuration(_advanceMinutes),
    );
    if (notificationAt.isAfter(DateTime.now())) {
      return null;
    }
    if (_advanceMinutes == 0) {
      return 'Elige una fecha y hora futuras para recibir la notificacion.';
    }
    return 'Elige una fecha y hora suficientemente futuras para avisarte ${formatAdvanceReminderLabel(_advanceMinutes)}.';
  }

  DateTime _suggestedDateTime() {
    final nextHour = DateTime.now().add(const Duration(hours: 1));
    return DateTime(nextHour.year, nextHour.month, nextHour.day, nextHour.hour);
  }

  Future<int?> _showCustomAdvanceDialog() async {
    final controller = TextEditingController(text: '$_advanceMinutes');
    String? errorText;

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Editar minutos'),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Minutos antes',
                  hintText: 'Ej. 25',
                  errorText: errorText,
                ),
                onChanged: (_) {
                  if (errorText != null) {
                    setDialogState(() {
                      errorText = null;
                    });
                  }
                },
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final parsedValue = int.tryParse(controller.text.trim());
                    if (parsedValue == null || parsedValue < 0) {
                      setDialogState(() {
                        errorText = 'Introduce 0 o un numero positivo.';
                      });
                      return;
                    }
                    Navigator.of(
                      context,
                    ).pop(normalizeAdvanceReminderMinutes(parsedValue));
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _pickRepeatInterval() async {
    final selectedInterval = await showModalBottomSheet<ReminderRepeatInterval>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Repetir recordatorio',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Si lo completas, la app programara automaticamente la siguiente repeticion.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 18),
                ...ReminderRepeatInterval.values.map(
                  (interval) => _AdvanceOptionTile(
                    label: interval.label,
                    subtitle: describeRepeatReminder(
                      interval,
                      repeatSettings: interval == ReminderRepeatInterval.monthly
                          ? _repeatSettings
                          : const ReminderRepeatSettings(),
                    ),
                    isSelected: _repeatInterval == interval,
                    onTap: () => Navigator.of(context).pop(interval),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selectedInterval == null) {
      return;
    }

    setState(() {
      _repeatInterval = selectedInterval;
      if (selectedInterval != ReminderRepeatInterval.monthly) {
        _repeatSettings = const ReminderRepeatSettings();
      }
    });
  }

  String get _formattedAdvanceLabel {
    if (_advanceMinutes == 0) {
      return 'A la hora exacta';
    }
    final label = formatAdvanceReminderLabel(_advanceMinutes);
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }

  bool _isPresetAdvanceOption(int minutes) {
    if (minutes == 0) {
      return true;
    }
    return _minuteAdvanceOptions.contains(minutes) ||
        _hourAdvanceOptions.contains(minutes);
  }

  String get _screenTitle {
    if (widget.isEditing) {
      if (_isShoppingListMode) {
        return 'Editar compra';
      }
      if (_isNoteMode) {
        return 'Editar nota';
      }
      if (_isTaskMode) {
        return 'Editar tarea';
      }
      return 'Editar recordatorio';
    }

    if (_isShoppingListMode) {
      return 'Lista de la Compra';
    }
    if (_isNoteMode) {
      return 'Nueva nota';
    }
    if (_isTaskMode) {
      return 'Nueva tarea';
    }
    return 'Nuevo recordatorio';
  }

  String get _introTitle {
    if (widget.isEditing) {
      if (_isShoppingListMode) {
        return 'Ajusta este producto de la lista de la compra.';
      }
      if (_isNoteMode) {
        return 'Ajusta el texto de esta nota.';
      }
      if (_isTaskMode) {
        return 'Ajusta el texto de esta tarea diaria.';
      }
      return 'Ajusta el titulo o la fecha del aviso.';
    }

    if (widget.draft != null) {
      return 'Ajusta el texto detectado por voz y confirma los datos.';
    }
    return 'Programa un recordatorio o guardalo como tarea, compra o nota.';
  }

  String get _introSubtitle {
    if (_isUnscheduledMode) {
      return 'Se guardara en el propio movil y seguira disponible cuando vuelvas a abrir la app.';
    }
    return 'La notificacion se guardara en el propio movil y seguira disponible cuando vuelvas a abrir la app.';
  }

  ReminderKind get _selectedKind {
    if (_isShoppingListMode) {
      return ReminderKind.shoppingList;
    }
    if (_isNoteMode) {
      return ReminderKind.note;
    }
    if (_isTaskMode) {
      return ReminderKind.task;
    }
    return ReminderKind.reminder;
  }

  void _setSelectedKind(ReminderKind kind) {
    setState(() {
      final wasUnscheduledMode = _isUnscheduledMode;
      _isShoppingListMode = kind == ReminderKind.shoppingList;
      _isNoteMode = kind == ReminderKind.note;
      _isTaskMode = kind == ReminderKind.task;
      if (_isUnscheduledMode) {
        _advanceMinutes = 0;
        _repeatInterval = ReminderRepeatInterval.none;
        _repeatSettings = const ReminderRepeatSettings();
      } else if (wasUnscheduledMode && _advanceMinutes == 0) {
        _advanceMinutes = defaultAdvanceReminderMinutesForKind(kind: kind);
      }
      _showDateError = false;
    });
  }

  bool get _isUnscheduledMode =>
      _isTaskMode || _isShoppingListMode || _isNoteMode;
}

class _KindSelector extends StatelessWidget {
  const _KindSelector({required this.selectedKind, required this.onChanged});

  final ReminderKind selectedKind;
  final ValueChanged<ReminderKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Tipo',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Elige donde quieres guardar este elemento.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _KindChoiceChip(
                icon: Icons.notifications_active_outlined,
                label: 'Recordatorio',
                kind: ReminderKind.reminder,
                selectedKind: selectedKind,
                onChanged: onChanged,
              ),
              _KindChoiceChip(
                icon: Icons.task_alt_rounded,
                label: 'Tarea',
                kind: ReminderKind.task,
                selectedKind: selectedKind,
                onChanged: onChanged,
              ),
              _KindChoiceChip(
                icon: Icons.shopping_basket_outlined,
                label: 'Compra',
                kind: ReminderKind.shoppingList,
                selectedKind: selectedKind,
                onChanged: onChanged,
              ),
              _KindChoiceChip(
                icon: Icons.sticky_note_2_outlined,
                label: 'Nota',
                kind: ReminderKind.note,
                selectedKind: selectedKind,
                onChanged: onChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KindChoiceChip extends StatelessWidget {
  const _KindChoiceChip({
    required this.icon,
    required this.label,
    required this.kind,
    required this.selectedKind,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final ReminderKind kind;
  final ReminderKind selectedKind;
  final ValueChanged<ReminderKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: selectedKind == kind,
      onSelected: (_) => onChanged(kind),
    );
  }
}

class _AdvanceSection extends StatelessWidget {
  const _AdvanceSection({
    required this.title,
    required this.options,
    required this.selectedMinutes,
  });

  final String title;
  final List<int> options;
  final int selectedMinutes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...options.map(
          (minutes) => _AdvanceOptionTile(
            label: _displayAdvanceOption(minutes),
            isSelected: selectedMinutes == minutes,
            onTap: () => Navigator.of(context).pop(minutes),
          ),
        ),
      ],
    );
  }

  String _displayAdvanceOption(int minutes) {
    if (minutes < 60) {
      return minutes == 1 ? '1 minuto antes' : '$minutes minutos antes';
    }

    final hours = minutes ~/ 60;
    if (minutes % 60 == 0) {
      return hours == 1 ? '1 hora antes' : '$hours horas antes';
    }

    return formatAdvanceReminderLabel(minutes);
  }
}

class _AdvanceOptionTile extends StatelessWidget {
  const _AdvanceOptionTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: isSelected ? FontWeight.w700 : null,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

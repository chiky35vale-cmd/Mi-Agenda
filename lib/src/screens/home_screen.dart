import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/reminder_controller.dart';
import '../models/reminder_draft.dart';
import '../models/reminder.dart';
import '../utils/month_week_sections.dart';
import '../utils/reminder_date_formatters.dart';
import '../utils/voice_reminder_parser.dart';
import 'daily_reminder_settings_screen.dart';
import 'reminder_form_screen.dart';
import 'voice_reminder_edit_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _lastHandledReminderOpenRequest = 0;
  bool _isOpeningReminderFromNotification = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<ReminderController>().requestPermissionsIfNeeded();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<ReminderController>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReminderController>();
    _maybeOpenReminderFromNotification(controller);
    final pendingTasks = controller.pendingTasks;
    final shoppingListItems = controller.pendingShoppingListItems;
    final pendingNotes = controller.pendingNotes;
    final pendingReminders = controller.pendingScheduledReminders;
    final completedReminders = controller.completedReminders;
    final completedScheduledReminders = completedReminders
        .where((reminder) => reminder.hasSchedule)
        .toList();
    final completedTasks = completedReminders
        .where((reminder) => reminder.isTask)
        .toList();
    final completedShoppingListItems = completedReminders
        .where((reminder) => reminder.isShoppingListItem)
        .toList();
    final completedNotes = completedReminders
        .where((reminder) => reminder.isNote)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Agenda'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Nuevo por voz',
            onPressed: () => _openVoiceCreate(context),
            icon: const Icon(Icons.mic_rounded),
          ),
          PopupMenuButton<_HomeSettingsAction>(
            tooltip: 'Configuracion',
            icon: const Icon(Icons.settings_rounded),
            onSelected: (action) {
              switch (action) {
                case _HomeSettingsAction.voiceEdit:
                  _openVoiceEdit(context);
                  return;
                case _HomeSettingsAction.dailySettings:
                  _openDailySettings(context);
                  return;
                case _HomeSettingsAction.refresh:
                  controller.refresh();
                  return;
              }
            },
            itemBuilder: (context) {
              return <PopupMenuEntry<_HomeSettingsAction>>[
                PopupMenuItem<_HomeSettingsAction>(
                  value: _HomeSettingsAction.voiceEdit,
                  enabled: controller.hasReminders,
                  child: const ListTile(
                    leading: Icon(Icons.record_voice_over_rounded),
                    title: Text('Editar por voz'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem<_HomeSettingsAction>(
                  value: _HomeSettingsAction.dailySettings,
                  child: ListTile(
                    leading: Icon(Icons.today_rounded),
                    title: Text('Configurar diario'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem<_HomeSettingsAction>(
                  value: _HomeSettingsAction.refresh,
                  child: ListTile(
                    leading: Icon(Icons.refresh_rounded),
                    title: Text('Actualizar'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 4,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _SummaryCard(
                          pendingCount: controller.pendingCount,
                          completedCount: controller.completedCount,
                          nextReminder: controller.nextReminder,
                        ),
                        const SizedBox(height: 8),
                        if (controller.errorMessage != null) ...<Widget>[
                          _ErrorBanner(
                            message: controller.errorMessage!,
                            onRetry: controller.refresh,
                          ),
                          const SizedBox(height: 8),
                        ],
                        const _HomeTabBar(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        _ReminderCategoryList(
                          pendingTitle: 'Recordatorios pendientes',
                          completedTitle: 'Recordatorios completados',
                          emptyTitle: 'Sin recordatorios',
                          emptyMessage:
                              'Crea un aviso con fecha y hora para verlo aqui.',
                          emptyIcon: Icons.notifications_none_rounded,
                          pendingReminders: pendingReminders,
                          completedReminders: completedScheduledReminders,
                          showWeekRows: true,
                          onRefresh: controller.refresh,
                          onCreate: () => _openForm(context),
                          onCreateForDate: (date) =>
                              _openFormForDate(context, date),
                          onOpen: (reminder) =>
                              _openForm(context, reminder: reminder),
                          onToggle: (reminder, value) =>
                              _toggleCompleted(context, reminder, value),
                          onDelete: (reminder) =>
                              _deleteReminder(context, reminder),
                          onSnooze: (reminder) =>
                              _snoozeReminder(context, reminder),
                        ),
                        _ReminderCategoryList(
                          pendingTitle: 'Tareas pendientes',
                          completedTitle: 'Tareas completadas',
                          emptyTitle: 'Sin tareas',
                          emptyMessage:
                              'Crea una tarea sin fecha para organizar lo que tienes que hacer.',
                          emptyIcon: Icons.task_alt_rounded,
                          pendingReminders: pendingTasks,
                          completedReminders: completedTasks,
                          onRefresh: controller.refresh,
                          onCreate: () =>
                              _openFormForKind(context, ReminderKind.task),
                          onOpen: (reminder) =>
                              _openForm(context, reminder: reminder),
                          onToggle: (reminder, value) =>
                              _toggleCompleted(context, reminder, value),
                          onDelete: (reminder) =>
                              _deleteReminder(context, reminder),
                        ),
                        _ReminderCategoryList(
                          pendingTitle: 'Compra pendiente',
                          completedTitle: 'Compra completada',
                          emptyTitle: 'Lista de la compra vacia',
                          emptyMessage:
                              'Anade productos por voz o desde el boton nuevo.',
                          emptyIcon: Icons.shopping_basket_outlined,
                          pendingReminders: shoppingListItems,
                          completedReminders: completedShoppingListItems,
                          onRefresh: controller.refresh,
                          onCreate: () => _openFormForKind(
                            context,
                            ReminderKind.shoppingList,
                          ),
                          onOpen: (reminder) =>
                              _openForm(context, reminder: reminder),
                          onToggle: (reminder, value) =>
                              _toggleCompleted(context, reminder, value),
                          onDelete: (reminder) =>
                              _deleteReminder(context, reminder),
                        ),
                        _ReminderCategoryList(
                          pendingTitle: 'Notas guardadas',
                          completedTitle: 'Notas archivadas',
                          emptyTitle: 'Sin notas',
                          emptyMessage:
                              'Guarda ideas, datos o textos rapidos sin fecha ni alarma.',
                          emptyIcon: Icons.sticky_note_2_outlined,
                          pendingReminders: pendingNotes,
                          completedReminders: completedNotes,
                          onRefresh: controller.refresh,
                          onCreate: () =>
                              _openFormForKind(context, ReminderKind.note),
                          onOpen: (reminder) =>
                              _openForm(context, reminder: reminder),
                          onToggle: (reminder, value) =>
                              _toggleCompleted(context, reminder, value),
                          onDelete: (reminder) =>
                              _deleteReminder(context, reminder),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo'),
      ),
    );
  }

  void _maybeOpenReminderFromNotification(ReminderController controller) {
    final reminderId = controller.pendingReminderOpenId;
    final pendingRequest = controller.pendingReminderOpenRequest;
    if (_isOpeningReminderFromNotification ||
        reminderId == null ||
        pendingRequest == _lastHandledReminderOpenRequest) {
      return;
    }

    _lastHandledReminderOpenRequest = pendingRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      _isOpeningReminderFromNotification = true;
      try {
        var reminder = controller.findReminderById(reminderId);
        if (reminder == null) {
          await controller.refresh();
          if (!mounted) {
            return;
          }
          reminder = controller.findReminderById(reminderId);
        }

        controller.clearPendingReminderOpen();
        if (!mounted) {
          return;
        }

        if (reminder == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ese recordatorio ya no esta disponible.'),
            ),
          );
          return;
        }

        await _openForm(context, reminder: reminder);
        if (mounted) {
          await controller.refresh();
        }
      } finally {
        _isOpeningReminderFromNotification = false;
      }
    });
  }

  Future<void> _openForm(
    BuildContext context, {
    Reminder? reminder,
    ReminderDraft? draft,
  }) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ReminderFormScreen(reminder: reminder, draft: draft),
      ),
    );
  }

  Future<void> _openVoiceCreate(BuildContext context) async {
    await Navigator.of(context).pushNamed('/voice-quick-create');
    if (context.mounted) {
      await context.read<ReminderController>().refresh();
    }
  }

  Future<void> _openFormForKind(BuildContext context, ReminderKind kind) {
    if (kind == ReminderKind.reminder) {
      return _openForm(context);
    }

    final now = DateTime.now();
    return _openForm(
      context,
      draft: ReminderDraft(
        title: '',
        scheduledAt: now,
        advanceReminderMinutes: 0,
        repeatInterval: ReminderRepeatInterval.none,
        kind: kind,
        hasSchedule: false,
      ),
    );
  }

  Future<void> _openFormForDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final selectedDay = _startOfDay(date);
    final today = _startOfDay(now);
    final scheduledAt = selectedDay == today
        ? _suggestedDateTimeFrom(now)
        : DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 9);

    return _openForm(
      context,
      draft: ReminderDraft(
        title: '',
        scheduledAt: scheduledAt,
        advanceReminderMinutes: defaultAdvanceReminderMinutesForKind(),
        repeatInterval: ReminderRepeatInterval.none,
      ),
    );
  }

  Future<void> _openVoiceEdit(BuildContext context) async {
    final controller = context.read<ReminderController>();
    final reminders = _numberedReminders(controller);
    final messenger = ScaffoldMessenger.of(context);

    if (reminders.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No hay recordatorios para editar por voz.'),
        ),
      );
      return;
    }

    final transcript = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => VoiceReminderEditSheet(reminders: reminders),
    );

    if (!context.mounted || transcript == null || transcript.trim().isEmpty) {
      return;
    }

    final command = parseVoiceReminderEditCommand(transcript);
    if (command == null || command.reminderNumber > reminders.length) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No encontre ese numero. Di algo como: "editar recordatorio 2 a las 12 y 35".',
          ),
        ),
      );
      return;
    }

    final reminder = reminders[command.reminderNumber - 1];
    final nextKind = command.scheduledAt == null
        ? reminder.kind
        : ReminderKind.reminder;
    if (!command.hasChanges) {
      await _openForm(context, reminder: reminder);
      return;
    }

    try {
      await controller.updateReminder(
        reminder,
        title: command.title ?? reminder.title,
        scheduledAt: command.scheduledAt ?? reminder.scheduledAt,
        advanceReminderMinutes:
            command.advanceReminderMinutes ?? reminder.advanceReminderMinutes,
        repeatInterval: command.repeatInterval ?? reminder.repeatInterval,
        repeatSettings: command.repeatInterval == null
            ? reminder.repeatSettings
            : command.repeatSettings ?? const ReminderRepeatSettings(),
        kind: nextKind,
        hasSchedule: nextKind == ReminderKind.reminder,
      );

      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Recordatorio ${command.reminderNumber} editado por voz.',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo editar el recordatorio por voz.'),
        ),
      );
    }
  }

  Future<void> _openDailySettings(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const DailyReminderSettingsScreen(),
      ),
    );
  }

  List<Reminder> _numberedReminders(ReminderController controller) {
    return <Reminder>[
      ...controller.pendingScheduledReminders,
      ...controller.pendingTasks,
      ...controller.pendingShoppingListItems,
      ...controller.pendingNotes,
      ...controller.completedReminders,
    ];
  }

  Future<void> _toggleCompleted(
    BuildContext context,
    Reminder reminder,
    bool isCompleted,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<ReminderController>().setCompleted(
        reminder,
        isCompleted,
      );
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isCompleted
                ? reminder.isRepeating
                      ? 'Repeticion completada. Ya esta programada la siguiente.'
                      : 'Recordatorio marcado como completado.'
                : 'Recordatorio reactivado.',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el estado del recordatorio.'),
        ),
      );
    }
  }

  Future<void> _deleteReminder(BuildContext context, Reminder reminder) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<ReminderController>().deleteReminder(reminder);
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Recordatorio eliminado.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar el recordatorio.')),
      );
    }
  }

  Future<void> _snoozeReminder(BuildContext context, Reminder reminder) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<ReminderController>().snoozeReminder(reminder);
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Recordatorio pospuesto 10 minutos.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo posponer el recordatorio.')),
      );
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.pendingCount,
    required this.completedCount,
    required this.nextReminder,
  });

  final int pendingCount;
  final int completedCount;
  final Reminder? nextReminder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: <Color>[
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                'Agenda',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              _StatPill(
                icon: Icons.notifications_active_rounded,
                label: 'Pend.',
                value: '$pendingCount',
              ),
              _StatPill(
                icon: Icons.task_alt_rounded,
                label: 'Comp.',
                value: '$completedCount',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            describeSummaryMessage(nextReminder, pendingCount),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.25),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(
            '$label $value',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.warning_rounded,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _HomeTabBar extends StatelessWidget {
  const _HomeTabBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: TabBar(
        isScrollable: true,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        labelColor: theme.colorScheme.onPrimary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        tabs: const <Widget>[
          Tab(text: 'Recordatorios'),
          Tab(text: 'Tareas'),
          Tab(text: 'Compra'),
          Tab(text: 'Notas'),
        ],
      ),
    );
  }
}

class _ReminderCategoryList extends StatelessWidget {
  const _ReminderCategoryList({
    required this.pendingTitle,
    required this.completedTitle,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.pendingReminders,
    required this.completedReminders,
    required this.onRefresh,
    required this.onCreate,
    required this.onOpen,
    required this.onToggle,
    required this.onDelete,
    this.showWeekRows = false,
    this.onCreateForDate,
    this.onSnooze,
  });

  final String pendingTitle;
  final String completedTitle;
  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;
  final List<Reminder> pendingReminders;
  final List<Reminder> completedReminders;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreate;
  final void Function(Reminder reminder) onOpen;
  final void Function(Reminder reminder, bool isCompleted) onToggle;
  final void Function(Reminder reminder) onDelete;
  final bool showWeekRows;
  final void Function(DateTime date)? onCreateForDate;
  final void Function(Reminder reminder)? onSnooze;

  bool get _hasItems =>
      pendingReminders.isNotEmpty || completedReminders.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: _buildChildren(),
      ),
    );
  }

  List<Widget> _buildChildren() {
    if (showWeekRows) {
      return _buildWeekChildren();
    }

    if (!_hasItems) {
      return <Widget>[
        _CategoryEmptyState(
          title: emptyTitle,
          message: emptyMessage,
          icon: emptyIcon,
          onCreate: onCreate,
        ),
      ];
    }

    return <Widget>[
      ..._buildPendingReminderTiles(
        title: pendingTitle,
        reminders: pendingReminders,
        numberOffset: 0,
      ),
      ..._buildCompletedReminderTiles(numberOffset: pendingReminders.length),
    ];
  }

  List<Widget> _buildWeekChildren() {
    final today = _startOfDay(DateTime.now());
    final monthSections = buildAvailableMonthWeekSections(today);
    final monthEnd = startOfNextMonth(today);
    final monthlyPendingReminders = pendingReminders
        .where(
          (reminder) => _isDateInsideRange(
            reminder.scheduledAt,
            start: today,
            end: monthEnd,
          ),
        )
        .toList();
    final otherPendingReminders = pendingReminders
        .where(
          (reminder) => !_isDateInsideRange(
            reminder.scheduledAt,
            start: today,
            end: monthEnd,
          ),
        )
        .toList();
    final remindersByDate = _groupRemindersByDay(monthlyPendingReminders);
    var nextNumber = 1;
    final children = <Widget>[];

    if (monthSections.isNotEmpty) {
      final firstSection = monthSections.first;
      final compactSections = monthSections.skip(1).toList();

      children
        ..add(_SectionLabel(title: formatMonthWeekSectionLabel(firstSection)))
        ..add(const SizedBox(height: 6));

      for (final day in firstSection.availableDates) {
        final dayReminders = remindersByDate[day] ?? const <Reminder>[];
        children.add(
          _WeekDayReminderRow(
            date: day,
            reminders: dayReminders,
            firstNumber: nextNumber,
            onCreate: () => (onCreateForDate ?? (_) => onCreate())(day),
            onOpen: onOpen,
            onToggle: onToggle,
            onDelete: onDelete,
            onSnooze: onSnooze,
          ),
        );
        nextNumber += dayReminders.length;
      }

      if (compactSections.isNotEmpty) {
        final compactFirstDate = compactSections.first.availableDates.first;
        final compactLastDate = compactSections.last.availableDates.last;
        children
          ..add(const SizedBox(height: 14))
          ..add(const _SectionLabel(title: 'Resto del mes'))
          ..add(const SizedBox(height: 6))
          ..add(
            _CompactMonthCalendar(
              rows: buildCompactMonthCalendarRows(
                firstDate: compactFirstDate,
                lastDate: compactLastDate,
              ),
              remindersByDate: remindersByDate,
              onCreateForDate: onCreateForDate ?? (_) => onCreate(),
              onOpen: onOpen,
            ),
          );
      }
    }

    if (otherPendingReminders.isNotEmpty) {
      children
        ..add(const SizedBox(height: 14))
        ..addAll(
          _buildPendingReminderTiles(
            title: 'Otros recordatorios pendientes',
            reminders: otherPendingReminders,
            numberOffset: nextNumber - 1,
          ),
        );
      nextNumber += otherPendingReminders.length;
    }

    children.addAll(_buildCompletedReminderTiles(numberOffset: nextNumber - 1));

    return children;
  }

  List<Widget> _buildPendingReminderTiles({
    required String title,
    required List<Reminder> reminders,
    required int numberOffset,
  }) {
    if (reminders.isEmpty) {
      return const <Widget>[];
    }

    return <Widget>[
      _SectionLabel(title: title),
      const SizedBox(height: 6),
      for (var index = 0; index < reminders.length; index += 1)
        _ReminderTile(
          number: numberOffset + index + 1,
          reminder: reminders[index],
          onTap: () => onOpen(reminders[index]),
          onToggle: (value) => onToggle(reminders[index], value),
          onDelete: () => onDelete(reminders[index]),
          onEdit: () => onOpen(reminders[index]),
          onSnooze: onSnooze == null ? null : () => onSnooze!(reminders[index]),
        ),
    ];
  }

  List<Widget> _buildCompletedReminderTiles({required int numberOffset}) {
    if (completedReminders.isEmpty) {
      return const <Widget>[];
    }

    return <Widget>[
      if (numberOffset > 0) const SizedBox(height: 14),
      _SectionLabel(title: completedTitle),
      const SizedBox(height: 6),
      for (var index = 0; index < completedReminders.length; index += 1)
        _ReminderTile(
          number: numberOffset + index + 1,
          reminder: completedReminders[index],
          onToggle: (value) => onToggle(completedReminders[index], value),
          onDelete: () => onDelete(completedReminders[index]),
          onReactivate: () => onToggle(completedReminders[index], false),
        ),
    ];
  }
}

class _CompactMonthCalendar extends StatelessWidget {
  const _CompactMonthCalendar({
    required this.rows,
    required this.remindersByDate,
    required this.onCreateForDate,
    required this.onOpen,
  });

  final List<List<DateTime?>> rows;
  final Map<DateTime, List<Reminder>> remindersByDate;
  final void Function(DateTime date) onCreateForDate;
  final void Function(Reminder reminder) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        child: Column(
          children: <Widget>[
            Row(
              children: _compactWeekdayLabels
                  .map(
                    (label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: row
                      .map(
                        (date) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: AspectRatio(
                              aspectRatio: 1.05,
                              child: _CompactCalendarDayCell(
                                date: date,
                                reminders: date == null
                                    ? const <Reminder>[]
                                    : remindersByDate[date] ??
                                          const <Reminder>[],
                                onTap: date == null
                                    ? null
                                    : () => _handleDateTap(context, date),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDateTap(BuildContext context, DateTime date) async {
    final reminders = remindersByDate[date] ?? const <Reminder>[];
    if (reminders.isEmpty) {
      onCreateForDate(date);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CalendarDayReminderSheet(
        date: date,
        reminders: reminders,
        onCreate: () => onCreateForDate(date),
        onOpen: onOpen,
      ),
    );
  }
}

class _CompactCalendarDayCell extends StatelessWidget {
  const _CompactCalendarDayCell({
    required this.date,
    required this.reminders,
    this.onTap,
  });

  final DateTime? date;
  final List<Reminder> reminders;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final hasReminders = reminders.isNotEmpty;
    final footerLabel = hasReminders
        ? reminders.length == 1
              ? formatReminderTime(reminders.first.scheduledAt)
              : '${reminders.length} avisos'
        : 'Libre';

    return Material(
      color: hasReminders
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.72)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${date!.day}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: hasReminders
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (hasReminders)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                footerLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  height: 1.15,
                  fontWeight: hasReminders ? FontWeight.w700 : FontWeight.w600,
                  color: hasReminders
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarDayReminderSheet extends StatelessWidget {
  const _CalendarDayReminderSheet({
    required this.date,
    required this.reminders,
    required this.onCreate,
    required this.onOpen,
  });

  final DateTime date;
  final List<Reminder> reminders;
  final VoidCallback onCreate;
  final void Function(Reminder reminder) onOpen;

  @override
  Widget build(BuildContext context) {
    final sortedReminders = List<Reminder>.from(reminders)
      ..sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              formatReminderDate(date),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${sortedReminders.length} avisos programados',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final reminder in sortedReminders)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: 54,
                  child: Text(
                    formatReminderTime(reminder.scheduledAt),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  reminder.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: describeReminderListDetails(reminder).isEmpty
                    ? null
                    : Text(
                        describeReminderListDetails(reminder).join(' | '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).pop();
                  onOpen(reminder);
                },
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onCreate();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo recordatorio este dia'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDayReminderRow extends StatelessWidget {
  const _WeekDayReminderRow({
    required this.date,
    required this.reminders,
    required this.firstNumber,
    required this.onCreate,
    required this.onOpen,
    required this.onToggle,
    required this.onDelete,
    this.onSnooze,
  });

  final DateTime date;
  final List<Reminder> reminders;
  final int firstNumber;
  final VoidCallback onCreate;
  final void Function(Reminder reminder) onOpen;
  final void Function(Reminder reminder, bool isCompleted) onToggle;
  final void Function(Reminder reminder) onDelete;
  final void Function(Reminder reminder)? onSnooze;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatWeekDayLabel(date),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Crear recordatorio este dia',
                    onPressed: onCreate,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              if (reminders.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 0, 8, 4),
                  child: Text(
                    'Disponible para nuevo mensaje',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else ...<Widget>[
                const SizedBox(height: 4),
                for (var index = 0; index < reminders.length; index += 1)
                  _ReminderTile(
                    number: firstNumber + index,
                    reminder: reminders[index],
                    onTap: () => onOpen(reminders[index]),
                    onToggle: (value) => onToggle(reminders[index], value),
                    onDelete: () => onDelete(reminders[index]),
                    onEdit: () => onOpen(reminders[index]),
                    onSnooze: onSnooze == null
                        ? null
                        : () => onSnooze!(reminders[index]),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryEmptyState extends StatelessWidget {
  const _CategoryEmptyState({
    required this.title,
    required this.message,
    required this.icon,
    required this.onCreate,
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 54, color: theme.colorScheme.primary),
          const SizedBox(height: 18),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuevo'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.number,
    required this.reminder,
    required this.onToggle,
    required this.onDelete,
    this.onTap,
    this.onEdit,
    this.onSnooze,
    this.onReactivate,
  });

  final int number;
  final Reminder reminder;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onSnooze;
  final VoidCallback? onReactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = reminder.isCompleted
        ? theme.colorScheme.primary
        : reminder.isOverdue
        ? theme.colorScheme.error
        : theme.colorScheme.secondary;
    final listDetails = describeReminderListDetails(reminder);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 13,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Text(
                    '$number',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Checkbox(
                  value: reminder.isCompleted,
                  visualDensity: VisualDensity.compact,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    onToggle(value);
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        reminder.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: reminder.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _ReminderLabelPill(
                        label: describeReminderListLabel(reminder),
                        color: statusColor,
                        isDate: reminder.hasSchedule,
                      ),
                      if (listDetails.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          listDetails.join(' | '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.2,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<_ReminderAction>(
                  onSelected: (action) {
                    switch (action) {
                      case _ReminderAction.edit:
                        onEdit?.call();
                        return;
                      case _ReminderAction.snooze:
                        onSnooze?.call();
                        return;
                      case _ReminderAction.reactivate:
                        onReactivate?.call();
                        return;
                      case _ReminderAction.delete:
                        onDelete();
                        return;
                    }
                  },
                  itemBuilder: (context) {
                    return <PopupMenuEntry<_ReminderAction>>[
                      if (!reminder.isCompleted)
                        const PopupMenuItem<_ReminderAction>(
                          value: _ReminderAction.edit,
                          child: Text('Editar'),
                        ),
                      if (!reminder.isCompleted && onSnooze != null)
                        const PopupMenuItem<_ReminderAction>(
                          value: _ReminderAction.snooze,
                          child: Text('Posponer 10 min'),
                        ),
                      if (reminder.isCompleted)
                        const PopupMenuItem<_ReminderAction>(
                          value: _ReminderAction.reactivate,
                          child: Text('Reactivar'),
                        ),
                      const PopupMenuItem<_ReminderAction>(
                        value: _ReminderAction.delete,
                        child: Text('Eliminar'),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderLabelPill extends StatelessWidget {
  const _ReminderLabelPill({
    required this.label,
    required this.color,
    required this.isDate,
  });

  final String label;
  final Color color;
  final bool isDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isDate ? 11 : 10,
          vertical: isDate ? 6 : 5,
        ),
        child: Text(
          label,
          style:
              (isDate
                      ? theme.textTheme.labelLarge
                      : theme.textTheme.labelMedium)
                  ?.copyWith(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

enum _ReminderAction { edit, snooze, reactivate, delete }

enum _HomeSettingsAction { voiceEdit, dailySettings, refresh }

const List<String> _compactWeekdayLabels = <String>[
  'L',
  'M',
  'X',
  'J',
  'V',
  'S',
  'D',
];

DateTime _startOfDay(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

Map<DateTime, List<Reminder>> _groupRemindersByDay(List<Reminder> reminders) {
  final grouped = <DateTime, List<Reminder>>{};
  for (final reminder in reminders) {
    final day = _startOfDay(reminder.scheduledAt);
    grouped.putIfAbsent(day, () => <Reminder>[]).add(reminder);
  }
  for (final entry in grouped.entries) {
    entry.value.sort(
      (left, right) => left.scheduledAt.compareTo(right.scheduledAt),
    );
  }
  return grouped;
}

DateTime _suggestedDateTimeFrom(DateTime now) {
  final nextHour = now.add(const Duration(hours: 1));
  return DateTime(nextHour.year, nextHour.month, nextHour.day, nextHour.hour);
}

bool _isDateInsideRange(
  DateTime dateTime, {
  required DateTime start,
  required DateTime end,
}) {
  return !dateTime.isBefore(start) && dateTime.isBefore(end);
}

String _formatWeekDayLabel(DateTime date) {
  final today = _startOfDay(DateTime.now());
  final target = _startOfDay(date);
  final dayLabel = formatReminderDate(date);

  if (target == today) {
    return 'Hoy, $dayLabel';
  }
  if (target == today.add(const Duration(days: 1))) {
    return 'Manana, $dayLabel';
  }
  return dayLabel;
}

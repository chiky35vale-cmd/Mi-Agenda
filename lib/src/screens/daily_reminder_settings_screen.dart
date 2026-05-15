import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/reminder_controller.dart';
import '../models/reminder.dart';
import '../models/reminder_draft.dart';
import '../utils/reminder_date_formatters.dart';
import 'reminder_form_screen.dart';

class DailyReminderSettingsScreen extends StatelessWidget {
  const DailyReminderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReminderController>();
    final dailyReminders =
        controller.reminders
            .where(
              (reminder) =>
                  reminder.repeatInterval == ReminderRepeatInterval.daily &&
                  !reminder.isCompleted,
            )
            .toList()
          ..sort(
            (left, right) => left.scheduledAt.compareTo(right.scheduledAt),
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Configuracion diaria')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: <Widget>[
            _DailySettingsHeader(onCreate: () => _openDailyForm(context)),
            const SizedBox(height: 18),
            if (dailyReminders.isEmpty)
              _EmptyDailyReminderState(onCreate: () => _openDailyForm(context))
            else
              for (var index = 0; index < dailyReminders.length; index += 1)
                _DailyReminderTile(
                  number: index + 1,
                  reminder: dailyReminders[index],
                  onEdit: () =>
                      _openDailyForm(context, reminder: dailyReminders[index]),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDailyForm(
    BuildContext context, {
    Reminder? reminder,
  }) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ReminderFormScreen(
          reminder: reminder,
          draft: reminder == null ? _buildDailyDraft() : null,
        ),
      ),
    );
  }

  ReminderDraft _buildDailyDraft() {
    final now = DateTime.now();
    var scheduledAt = DateTime(now.year, now.month, now.day, 9);
    if (!scheduledAt.isAfter(now)) {
      scheduledAt = scheduledAt.add(const Duration(days: 1));
    }
    return ReminderDraft(
      title: 'Recordatorio diario',
      scheduledAt: scheduledAt,
      advanceReminderMinutes: defaultAdvanceReminderMinutesForKind(),
      repeatInterval: ReminderRepeatInterval.daily,
    );
  }
}

class _DailySettingsHeader extends StatelessWidget {
  const _DailySettingsHeader({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Recordatorio diario',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aqui puedes editar los avisos que se repiten cada dia o crear uno nuevo ya configurado como diario.',
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear diario'),
          ),
        ],
      ),
    );
  }
}

class _EmptyDailyReminderState extends StatelessWidget {
  const _EmptyDailyReminderState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: <Widget>[
          Icon(Icons.today_rounded, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            'No hay recordatorio diario activo',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Pulsa crear diario y ajusta el texto, la hora y los minutos de aviso.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Configurar ahora'),
          ),
        ],
      ),
    );
  }
}

class _DailyReminderTile extends StatelessWidget {
  const _DailyReminderTile({
    required this.number,
    required this.reminder,
    required this.onEdit,
  });

  final int number;
  final Reminder reminder;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
            child: Text('$number'),
          ),
          title: Text(
            reminder.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '${formatReminderTime(reminder.scheduledAt)} - ${describeReminderAlert(reminder)}',
          ),
          trailing: IconButton(
            tooltip: 'Editar diario',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded),
          ),
          onTap: onEdit,
        ),
      ),
    );
  }
}

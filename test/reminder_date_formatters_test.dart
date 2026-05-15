import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:recordatorio/src/models/reminder.dart';
import 'package:recordatorio/src/utils/reminder_date_formatters.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES');
  });

  group('describeReadableReminderParagraph', () {
    test('presenta recordatorios como parrafos comprensibles', () {
      final reminder = Reminder(
        title: 'llamar llamar al medico',
        scheduledAt: DateTime(2026, 4, 7, 9, 0),
        createdAt: DateTime(2026, 4, 6, 10, 0),
        updatedAt: DateTime(2026, 4, 6, 10, 0),
        advanceReminderMinutes: 10,
        repeatInterval: ReminderRepeatInterval.none,
        isCompleted: false,
      );

      final paragraph = describeReadableReminderParagraph(reminder);

      expect(paragraph, contains('Recordatorio: Llamar al medico.'));
      expect(paragraph, contains('Programado para'));
      expect(paragraph, contains('Te avisare'));
    });
  });

  group('describeReminderListLabel', () {
    test('usa etiquetas cortas sin repetir el titulo', () {
      final scheduledReminder = Reminder(
        title: 'pagar alquiler',
        scheduledAt: DateTime(2099, 4, 7, 9, 0),
        createdAt: DateTime(2099, 4, 6, 10, 0),
        updatedAt: DateTime(2099, 4, 6, 10, 0),
        advanceReminderMinutes: 0,
        repeatInterval: ReminderRepeatInterval.none,
        isCompleted: false,
      );
      final task = scheduledReminder.copyWith(
        kind: ReminderKind.task,
        hasSchedule: false,
      );
      final shoppingItem = scheduledReminder.copyWith(
        kind: ReminderKind.shoppingList,
        hasSchedule: false,
      );
      final note = scheduledReminder.copyWith(
        kind: ReminderKind.note,
        hasSchedule: false,
      );

      expect(describeReminderListLabel(scheduledReminder), contains('09:00'));
      expect(describeReminderListLabel(task), 'Tarea Pendiente');
      expect(describeReminderListLabel(shoppingItem), 'Compra Pendiente');
      expect(describeReminderListLabel(note), 'Nota');
    });
  });

  group('describeReminderListDetails', () {
    test('omite detalles redundantes para tareas y compras', () {
      final reminder = Reminder(
        title: 'comprar leche',
        scheduledAt: DateTime(2099, 4, 7, 9, 0),
        createdAt: DateTime(2099, 4, 6, 10, 0),
        updatedAt: DateTime(2099, 4, 6, 10, 0),
        advanceReminderMinutes: 0,
        repeatInterval: ReminderRepeatInterval.none,
        isCompleted: false,
        kind: ReminderKind.shoppingList,
        hasSchedule: false,
      );

      expect(describeReminderListDetails(reminder), isEmpty);
    });

    test('muestra fecha y solo avisos utiles', () {
      final reminder = Reminder(
        title: 'pagar alquiler',
        scheduledAt: DateTime(2099, 4, 7, 9, 0),
        createdAt: DateTime(2099, 4, 6, 10, 0),
        updatedAt: DateTime(2099, 4, 6, 10, 0),
        advanceReminderMinutes: 15,
        repeatInterval: ReminderRepeatInterval.daily,
        isCompleted: false,
      );

      final details = describeReminderListDetails(reminder);

      expect(details, hasLength(2));
      expect(details, contains('Aviso 15 minutos antes'));
      expect(details, contains('Repite cada dia'));
    });
  });
}

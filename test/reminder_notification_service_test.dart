import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:recordatorio/src/models/reminder.dart';
import 'package:recordatorio/src/services/reminder_notification_service.dart';

Future<void> main() async {
  await initializeDateFormatting('es_ES');

  group('daily agenda notification helpers', () {
    test('programa la agenda de hoy si todavia no han dado las ocho', () {
      final now = DateTime(2026, 4, 8, 7, 15);

      final scheduledAt = nextDailyAgendaNotificationTime(now);

      expect(scheduledAt, DateTime(2026, 4, 8, 8, 0));
    });

    test('programa la agenda de manana si ya han dado las ocho', () {
      final now = DateTime(2026, 4, 8, 8, 5);

      final scheduledAt = nextDailyAgendaNotificationTime(now);

      expect(scheduledAt, DateTime(2026, 4, 9, 8, 0));
    });

    test('abre el recordatorio correcto al tocar la notificacion', () {
      final reminderId = reminderIdToOpenFromNotificationTap(
        openedFromNotificationBody: true,
        notificationId: 42,
      );

      expect(reminderId, 42);
    });

    test('usa el payload si Android no devuelve id en el toque', () {
      final reminderId = reminderIdToOpenFromNotificationTap(
        openedFromNotificationBody: true,
        payload: '17',
      );

      expect(reminderId, 17);
    });

    test('no abre edicion al pulsar una accion de la notificacion', () {
      final reminderId = reminderIdToOpenFromNotificationTap(
        openedFromNotificationBody: false,
        notificationId: 42,
        payload: '42',
      );

      expect(reminderId, isNull);
    });

    test('resume la agenda del dia con los primeros recordatorios', () {
      final agendaDate = DateTime(2026, 4, 8);
      final reminders = <Reminder>[
        _buildReminder(
          id: 1,
          title: 'Llamar al dentista',
          scheduledAt: DateTime(2026, 4, 8, 9, 0),
        ),
        _buildReminder(
          id: 2,
          title: 'Comprar pan',
          scheduledAt: DateTime(2026, 4, 8, 13, 30),
        ),
        _buildReminder(
          id: 3,
          title: 'Pagar alquiler',
          scheduledAt: DateTime(2026, 4, 8, 18, 0),
        ),
        _buildReminder(
          id: 4,
          title: 'Sacar basura',
          scheduledAt: DateTime(2026, 4, 8, 22, 0),
        ),
      ];

      final body = buildDailyAgendaNotificationBody(reminders, agendaDate);

      expect(
        body,
        'Tu agenda de hoy: 09:00 Llamar al dentista, 13:30 Comprar pan, 18:00 Pagar alquiler y 1 mas.',
      );
    });

    test('resume tambien tareas sin fecha en la agenda diaria', () {
      final agendaDate = DateTime(2026, 4, 8);
      final reminders = <Reminder>[
        _buildReminder(
          id: 1,
          title: 'Comprar pan',
          scheduledAt: DateTime(2026, 4, 7, 10, 0),
          kind: ReminderKind.task,
          hasSchedule: false,
        ),
        _buildReminder(
          id: 2,
          title: 'Llamar al dentista',
          scheduledAt: DateTime(2026, 4, 8, 9, 0),
        ),
      ];

      final body = buildDailyAgendaNotificationBody(reminders, agendaDate);

      expect(
        body,
        'Tu agenda de hoy: 09:00 Llamar al dentista, Tarea: Comprar pan.',
      );
    });

    test('muestra tareas pendientes en la pantalla bloqueada', () {
      final reminders = <Reminder>[
        _buildReminder(
          id: 1,
          title: 'Comprar pan',
          scheduledAt: DateTime(2026, 4, 7, 10, 0),
          kind: ReminderKind.task,
          hasSchedule: false,
        ),
        _buildReminder(
          id: 2,
          title: 'Llamar a mama',
          scheduledAt: DateTime(2026, 4, 7, 11, 0),
          kind: ReminderKind.task,
          hasSchedule: false,
        ),
        _buildReminder(
          id: 3,
          title: 'Pagar luz',
          scheduledAt: DateTime(2026, 4, 7, 12, 0),
          kind: ReminderKind.task,
          hasSchedule: false,
        ),
      ];

      final body = buildLockScreenTaskBody(reminders);

      expect(
        body,
        '3 puntos pendientes: Tarea: Comprar pan, Tarea: Llamar a mama, Tarea: Pagar luz.',
      );
    });

    test('omite la compra en el resumen de pantalla bloqueada', () {
      final today = DateTime.now();
      final agendaDate = DateTime(today.year, today.month, today.day);
      final reminders = <Reminder>[
        _buildReminder(
          id: 1,
          title: 'Comprar pan',
          scheduledAt: DateTime(2026, 4, 7, 10, 0),
          kind: ReminderKind.task,
          hasSchedule: false,
        ),
        _buildReminder(
          id: 2,
          title: 'Leche',
          scheduledAt: DateTime(2026, 4, 7, 11, 0),
          kind: ReminderKind.shoppingList,
          hasSchedule: false,
        ),
        _buildReminder(
          id: 3,
          title: 'Llamar al dentista',
          scheduledAt: DateTime(
            agendaDate.year,
            agendaDate.month,
            agendaDate.day,
            9,
          ),
        ),
      ];

      final body = buildLockScreenTaskBody(reminders);

      expect(
        body,
        '2 puntos pendientes: 09:00 Llamar al dentista, Tarea: Comprar pan.',
      );
    });

    test('no muestra texto tutorial en el resumen de pantalla bloqueada', () {
      final today = DateTime.now();
      final agendaDate = DateTime(today.year, today.month, today.day);
      final reminders = <Reminder>[
        _buildReminder(
          id: 1,
          title: 'Llamar al dentista',
          scheduledAt: DateTime(
            agendaDate.year,
            agendaDate.month,
            agendaDate.day,
            9,
          ),
        ),
        _buildReminder(
          id: 2,
          title: 'Comprar pan',
          scheduledAt: DateTime(2026, 4, 7, 10, 0),
          kind: ReminderKind.task,
          hasSchedule: false,
        ),
        _buildReminder(
          id: 3,
          title: 'Pagar alquiler',
          scheduledAt: DateTime(
            agendaDate.year,
            agendaDate.month,
            agendaDate.day,
            18,
          ),
        ),
        _buildReminder(
          id: 4,
          title: 'Sacar basura',
          scheduledAt: DateTime(2026, 4, 7, 11, 0),
          kind: ReminderKind.task,
          hasSchedule: false,
        ),
      ];

      final body = buildLockScreenTaskBody(reminders);

      expect(
        body,
        '4 puntos pendientes: 09:00 Llamar al dentista, 18:00 Pagar alquiler, Tarea: Comprar pan y 1 mas.',
      );
      expect(body, isNot(contains('Desliza')));
    });

    test('muestra mensaje de tareas vacias en la pantalla bloqueada', () {
      final body = buildLockScreenTaskBody(<Reminder>[]);

      expect(
        body,
        'No hay tareas ni recordatorios pendientes. Toca para crear uno por voz.',
      );
    });

    test('desglosa itinerario completo para pantalla bloqueada', () {
      final agendaDate = DateTime(2026, 4, 8);
      final reminders = <Reminder>[
        _buildReminder(
          id: 1,
          title: 'Comprar pan',
          scheduledAt: DateTime(2026, 4, 7, 10, 0),
          kind: ReminderKind.task,
          hasSchedule: false,
        ),
        _buildReminder(
          id: 2,
          title: 'Leche',
          scheduledAt: DateTime(2026, 4, 7, 11, 0),
          kind: ReminderKind.shoppingList,
          hasSchedule: false,
        ),
        _buildReminder(
          id: 3,
          title: 'Llamar al dentista',
          scheduledAt: DateTime(2026, 4, 8, 9, 0),
        ),
      ];

      final expandedBody = buildLockScreenItineraryExpandedBody(
        reminders,
        agendaDate,
      );

      expect(expandedBody, contains('Tareas pendientes'));
      expect(expandedBody, contains('1. Comprar pan.'));
      expect(expandedBody, contains('Recordatorios con hora'));
      expect(expandedBody, contains('09:00 - Llamar al dentista.'));
      expect(expandedBody, isNot(contains('Lista de la compra')));
      expect(expandedBody, isNot(contains('Leche.')));
      expect(expandedBody, isNot(contains('Desliza hacia abajo')));
      expect(
        expandedBody.indexOf('Recordatorios con hora'),
        lessThan(expandedBody.indexOf('Tareas pendientes')),
      );
    });

    test('indica cuando no hay agenda pendiente para hoy', () {
      final agendaDate = DateTime(2026, 4, 8);

      final body = buildDailyAgendaNotificationBody(<Reminder>[], agendaDate);

      expect(body, 'Hoy no tienes tareas ni recordatorios pendientes.');
    });
  });
}

Reminder _buildReminder({
  int? id,
  required String title,
  required DateTime scheduledAt,
  ReminderKind kind = ReminderKind.reminder,
  bool hasSchedule = true,
  bool isCompleted = false,
}) {
  final createdAt = DateTime(2026, 4, 7, 10, 0);
  return Reminder(
    id: id,
    title: title,
    scheduledAt: scheduledAt,
    advanceReminderMinutes: 0,
    repeatInterval: ReminderRepeatInterval.none,
    isCompleted: isCompleted,
    createdAt: createdAt,
    updatedAt: createdAt,
    kind: kind,
    hasSchedule: hasSchedule,
  );
}

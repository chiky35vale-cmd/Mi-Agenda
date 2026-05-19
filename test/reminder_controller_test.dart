import 'package:flutter_test/flutter_test.dart';
import 'package:mi_agenda/src/controllers/reminder_controller.dart';
import 'package:mi_agenda/src/data/reminder_repository.dart';
import 'package:mi_agenda/src/models/reminder.dart';
import 'package:mi_agenda/src/services/reminder_notification_service.dart';

void main() {
  group('ReminderController', () {
    test('carga recordatorios y sincroniza solo los avisos futuros', () async {
      final now = DateTime.now();
      final repository = FakeReminderRepository(
        seed: <Reminder>[
          buildReminder(id: 1, scheduledAt: now.add(const Duration(hours: 2))),
          buildReminder(
            id: 2,
            scheduledAt: now.subtract(const Duration(hours: 1)),
          ),
          buildReminder(
            id: 3,
            scheduledAt: now.add(const Duration(days: 1)),
            isCompleted: true,
          ),
          buildReminder(
            id: 4,
            scheduledAt: now.add(const Duration(hours: 26)),
            advanceReminderMinutes: 1440,
          ),
          buildReminder(
            id: 5,
            scheduledAt: now.subtract(const Duration(hours: 3)),
            snoozedUntil: now.add(const Duration(minutes: 10)),
          ),
        ],
      );
      final notifications = FakeReminderNotificationService();
      final controller = ReminderController(
        repository: repository,
        notificationService: notifications,
      );

      await controller.initialize();

      expect(controller.pendingCount, 4);
      expect(controller.completedCount, 1);
      expect(notifications.syncedIds, unorderedEquals(<int>[1, 4, 5]));
    });

    test('crea un recordatorio y programa su notificacion', () async {
      final repository = FakeReminderRepository();
      final notifications = FakeReminderNotificationService();
      final controller = ReminderController(
        repository: repository,
        notificationService: notifications,
      );

      await controller.initialize();
      await controller.createReminder(
        title: 'Comprar pan',
        scheduledAt: DateTime.now().add(const Duration(hours: 4)),
        advanceReminderMinutes: 45,
        repeatInterval: ReminderRepeatInterval.none,
      );

      expect(controller.pendingCount, 1);
      expect(repository.items.single.title, 'Comprar pan');
      expect(repository.items.single.advanceReminderMinutes, 45);
      expect(notifications.syncedIds, <int>[1]);
    });

    test('crea una tarea sin fecha y no programa notificacion', () async {
      final repository = FakeReminderRepository();
      final notifications = FakeReminderNotificationService();
      final controller = ReminderController(
        repository: repository,
        notificationService: notifications,
      );

      await controller.initialize();
      await controller.createTask(title: 'Comprar pan');

      expect(controller.pendingTaskCount, 1);
      expect(repository.items.single.title, 'Comprar pan');
      expect(repository.items.single.kind, ReminderKind.task);
      expect(repository.items.single.hasSchedule, isFalse);
      expect(notifications.syncedIds, isEmpty);
    });

    test(
      'crea un producto de compra sin fecha y no programa notificacion',
      () async {
        final repository = FakeReminderRepository();
        final notifications = FakeReminderNotificationService();
        final controller = ReminderController(
          repository: repository,
          notificationService: notifications,
        );

        await controller.initialize();
        await controller.createShoppingListItem(title: 'Leche');

        expect(controller.pendingShoppingListCount, 1);
        expect(repository.items.single.title, 'Leche');
        expect(repository.items.single.kind, ReminderKind.shoppingList);
        expect(repository.items.single.hasSchedule, isFalse);
        expect(repository.items.single.isShoppingListItem, isTrue);
        expect(repository.items.single.isTask, isFalse);
        expect(notifications.syncedIds, isEmpty);
      },
    );

    test('crea una nota sin fecha y no la mezcla con tareas', () async {
      final repository = FakeReminderRepository();
      final notifications = FakeReminderNotificationService();
      final controller = ReminderController(
        repository: repository,
        notificationService: notifications,
      );

      await controller.initialize();
      await controller.createNote(title: 'Ideas para el viaje');

      expect(controller.pendingNoteCount, 1);
      expect(controller.pendingTaskCount, 0);
      expect(repository.items.single.title, 'Ideas para el viaje');
      expect(repository.items.single.kind, ReminderKind.note);
      expect(repository.items.single.hasSchedule, isFalse);
      expect(repository.items.single.isNote, isTrue);
      expect(repository.items.single.isTask, isFalse);
      expect(notifications.syncedIds, isEmpty);
    });

    test('marcar y reactivar un recordatorio actualiza sus avisos', () async {
      final reminder = buildReminder(
        id: 1,
        scheduledAt: DateTime.now().add(const Duration(hours: 3)),
      );
      final repository = FakeReminderRepository(seed: <Reminder>[reminder]);
      final notifications = FakeReminderNotificationService();
      final controller = ReminderController(
        repository: repository,
        notificationService: notifications,
      );

      await controller.initialize();
      notifications.reset();

      await controller.setCompleted(reminder, true);
      expect(controller.completedCount, 1);
      expect(notifications.syncedIds, isEmpty);

      final completedReminder = controller.completedReminders.single;
      notifications.reset();

      await controller.setCompleted(completedReminder, false);
      expect(controller.pendingCount, 1);
      expect(notifications.syncedIds, <int>[1]);
    });

    test(
      'completar un recordatorio repetitivo programa la siguiente ocurrencia',
      () async {
        final baseDate = DateTime.now().add(const Duration(hours: 3));
        final reminder = buildReminder(
          id: 1,
          scheduledAt: baseDate,
          repeatInterval: ReminderRepeatInterval.daily,
        );
        final repository = FakeReminderRepository(seed: <Reminder>[reminder]);
        final notifications = FakeReminderNotificationService();
        final controller = ReminderController(
          repository: repository,
          notificationService: notifications,
        );

        await controller.initialize();
        notifications.reset();

        await controller.setCompleted(reminder, true);

        expect(controller.pendingCount, 1);
        expect(controller.completedCount, 0);
        expect(
          repository.items.single.scheduledAt,
          nextReminderOccurrence(baseDate, ReminderRepeatInterval.daily),
        );
        expect(notifications.syncedIds, <int>[1]);
      },
    );

    test(
      'completar un recordatorio mensual por primer lunes conserva el patron',
      () async {
        final baseDate = DateTime(2026, 5, 4, 9, 0);
        final reminder = buildReminder(
          id: 1,
          scheduledAt: baseDate,
          repeatInterval: ReminderRepeatInterval.monthly,
          repeatSettings: const ReminderRepeatSettings(
            monthWeekOfMonth: 1,
            monthWeekday: DateTime.monday,
          ),
        );
        final repository = FakeReminderRepository(seed: <Reminder>[reminder]);
        final notifications = FakeReminderNotificationService();
        final controller = ReminderController(
          repository: repository,
          notificationService: notifications,
        );

        await controller.initialize();
        notifications.reset();

        await controller.setCompleted(reminder, true);

        expect(controller.pendingCount, 1);
        expect(repository.items.single.scheduledAt, DateTime(2026, 6, 1, 9, 0));
        expect(repository.items.single.repeatSettings.monthWeekOfMonth, 1);
        expect(
          repository.items.single.repeatSettings.monthWeekday,
          DateTime.monday,
        );
        expect(notifications.syncedIds, <int>[1]);
      },
    );

    test(
      'completar un recordatorio mensual por ultimo viernes conserva el patron',
      () async {
        final baseDate = DateTime(2026, 4, 24, 18, 0);
        final reminder = buildReminder(
          id: 1,
          scheduledAt: baseDate,
          repeatInterval: ReminderRepeatInterval.monthly,
          repeatSettings: const ReminderRepeatSettings(
            monthWeekOfMonth: 5,
            monthWeekday: DateTime.friday,
          ),
        );
        final repository = FakeReminderRepository(seed: <Reminder>[reminder]);
        final notifications = FakeReminderNotificationService();
        final controller = ReminderController(
          repository: repository,
          notificationService: notifications,
        );

        await controller.initialize();
        notifications.reset();

        await controller.setCompleted(reminder, true);

        expect(controller.pendingCount, 1);
        expect(
          repository.items.single.scheduledAt,
          DateTime(2026, 5, 29, 18, 0),
        );
        expect(repository.items.single.repeatSettings.monthWeekOfMonth, 5);
        expect(
          repository.items.single.repeatSettings.monthWeekday,
          DateTime.friday,
        );
        expect(notifications.syncedIds, <int>[1]);
      },
    );

    test(
      'completar un recordatorio mensual por penultimo viernes conserva el patron',
      () async {
        final baseDate = DateTime(2026, 4, 17, 18, 0);
        final reminder = buildReminder(
          id: 1,
          scheduledAt: baseDate,
          repeatInterval: ReminderRepeatInterval.monthly,
          repeatSettings: const ReminderRepeatSettings(
            monthWeekFromEnd: 2,
            monthWeekday: DateTime.friday,
          ),
        );
        final repository = FakeReminderRepository(seed: <Reminder>[reminder]);
        final notifications = FakeReminderNotificationService();
        final controller = ReminderController(
          repository: repository,
          notificationService: notifications,
        );

        await controller.initialize();
        notifications.reset();

        await controller.setCompleted(reminder, true);

        expect(controller.pendingCount, 1);
        expect(
          repository.items.single.scheduledAt,
          DateTime(2026, 5, 22, 18, 0),
        );
        expect(repository.items.single.repeatSettings.monthWeekFromEnd, 2);
        expect(
          repository.items.single.repeatSettings.monthWeekday,
          DateTime.friday,
        );
        expect(notifications.syncedIds, <int>[1]);
      },
    );

    test(
      'posponer un recordatorio guarda la nueva hora y reprograma el aviso',
      () async {
        final reminder = buildReminder(
          id: 1,
          scheduledAt: DateTime.now().add(const Duration(hours: 3)),
        );
        final repository = FakeReminderRepository(seed: <Reminder>[reminder]);
        final notifications = FakeReminderNotificationService();
        final controller = ReminderController(
          repository: repository,
          notificationService: notifications,
        );

        await controller.initialize();
        notifications.reset();

        await controller.snoozeReminder(
          reminder,
          duration: const Duration(minutes: 15),
        );

        expect(repository.items.single.snoozedUntil, isNotNull);
        expect(notifications.syncedIds, <int>[1]);
      },
    );

    test('elimina un recordatorio y cancela su notificacion', () async {
      final reminder = buildReminder(
        id: 1,
        scheduledAt: DateTime.now().add(const Duration(days: 2)),
      );
      final repository = FakeReminderRepository(seed: <Reminder>[reminder]);
      final notifications = FakeReminderNotificationService();
      final controller = ReminderController(
        repository: repository,
        notificationService: notifications,
      );

      await controller.initialize();
      notifications.reset();

      await controller.deleteReminder(reminder);

      expect(controller.hasReminders, isFalse);
      expect(notifications.syncedIds, isEmpty);
    });

    test('guarda solicitudes de apertura desde notificacion', () async {
      final repository = FakeReminderRepository();
      final notifications = FakeReminderNotificationService();
      final controller = ReminderController(
        repository: repository,
        notificationService: notifications,
      );

      await controller.initialize();

      expect(controller.pendingReminderOpenId, isNull);
      expect(controller.pendingReminderOpenRequest, 0);

      controller.requestReminderOpen(7);
      expect(controller.pendingReminderOpenId, 7);
      expect(controller.pendingReminderOpenRequest, 1);

      controller.clearPendingReminderOpen();
      expect(controller.pendingReminderOpenId, isNull);
      expect(controller.pendingReminderOpenRequest, 1);

      controller.requestReminderOpen(7);
      expect(controller.pendingReminderOpenId, 7);
      expect(controller.pendingReminderOpenRequest, 2);
    });
  });
}

Reminder buildReminder({
  int? id,
  required DateTime scheduledAt,
  bool isCompleted = false,
  int advanceReminderMinutes = 0,
  ReminderRepeatInterval repeatInterval = ReminderRepeatInterval.none,
  ReminderRepeatSettings repeatSettings = const ReminderRepeatSettings(),
  DateTime? snoozedUntil,
}) {
  final createdAt = DateTime.now().subtract(const Duration(days: 1));
  return Reminder(
    id: id,
    title: 'Recordatorio ${id ?? 0}',
    scheduledAt: scheduledAt,
    advanceReminderMinutes: advanceReminderMinutes,
    repeatInterval: repeatInterval,
    repeatSettings: repeatSettings,
    isCompleted: isCompleted,
    createdAt: createdAt,
    updatedAt: createdAt,
    snoozedUntil: snoozedUntil,
  );
}

class FakeReminderRepository implements ReminderRepository {
  FakeReminderRepository({List<Reminder>? seed}) {
    if (seed != null) {
      items.addAll(seed);
      final ids = seed.map((item) => item.id ?? 0).toList();
      final highestId = ids.isEmpty
          ? 0
          : ids.reduce((left, right) => left > right ? left : right);
      _nextId = highestId + 1;
    }
  }

  final List<Reminder> items = <Reminder>[];
  int _nextId = 1;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<Reminder>> fetchAll() async {
    return List<Reminder>.from(items);
  }

  @override
  Future<Reminder?> fetchById(int reminderId) async {
    try {
      return items.firstWhere((item) => item.id == reminderId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Reminder> insert(Reminder reminder) async {
    final storedReminder = reminder.copyWith(id: _nextId);
    _nextId += 1;
    items.add(storedReminder);
    return storedReminder;
  }

  @override
  Future<Reminder> update(Reminder reminder) async {
    final index = items.indexWhere((item) => item.id == reminder.id);
    items[index] = reminder;
    return reminder;
  }

  @override
  Future<void> delete(int reminderId) async {
    items.removeWhere((item) => item.id == reminderId);
  }
}

class FakeReminderNotificationService implements ReminderNotificationService {
  final List<int> scheduledIds = <int>[];
  final List<int> cancelledIds = <int>[];
  final List<int> syncedIds = <int>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> scheduleReminder(Reminder reminder) async {
    if (reminder.id != null) {
      scheduledIds.add(reminder.id!);
    }
  }

  @override
  Future<void> cancelReminder(int reminderId) async {
    cancelledIds.add(reminderId);
  }

  @override
  Future<void> syncReminders(Iterable<Reminder> reminders) async {
    syncedIds
      ..clear()
      ..addAll(
        reminders
            .where((reminder) => reminder.shouldNotify && reminder.id != null)
            .map((reminder) => reminder.id!),
      );
  }

  void reset() {
    scheduledIds.clear();
    cancelledIds.clear();
    syncedIds.clear();
  }
}

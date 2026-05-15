import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../data/reminder_repository.dart';
import '../models/reminder.dart';
import '../services/reminder_notification_service.dart';
import '../utils/voice_text_polisher.dart';

const Duration defaultReminderSnoozeDuration = Duration(minutes: 10);

class ReminderController extends ChangeNotifier {
  ReminderController({
    required ReminderRepository repository,
    required ReminderNotificationService notificationService,
  }) : _repository = repository,
       _notificationService = notificationService;

  final ReminderRepository _repository;
  final ReminderNotificationService _notificationService;

  final List<Reminder> _reminders = <Reminder>[];
  bool _isLoading = true;
  bool _permissionsRequested = false;
  String? _errorMessage;
  int? _pendingReminderOpenId;
  int _pendingReminderOpenRequest = 0;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasReminders => _reminders.isNotEmpty;
  int get pendingCount => pendingReminders.length;
  int get completedCount => completedReminders.length;
  int get pendingTaskCount => pendingTasks.length;
  int get pendingShoppingListCount => pendingShoppingListItems.length;
  int get pendingNoteCount => pendingNotes.length;
  int? get pendingReminderOpenId => _pendingReminderOpenId;
  int get pendingReminderOpenRequest => _pendingReminderOpenRequest;

  UnmodifiableListView<Reminder> get reminders =>
      UnmodifiableListView<Reminder>(_reminders);

  List<Reminder> get pendingReminders {
    final items = _reminders
        .where((reminder) => !reminder.isCompleted)
        .toList();
    items.sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));
    return items;
  }

  List<Reminder> get pendingTasks {
    final items = _reminders
        .where((reminder) => !reminder.isCompleted && reminder.isTask)
        .toList();
    items.sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return items;
  }

  List<Reminder> get pendingShoppingListItems {
    final items = _reminders
        .where(
          (reminder) => !reminder.isCompleted && reminder.isShoppingListItem,
        )
        .toList();
    items.sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return items;
  }

  List<Reminder> get pendingNotes {
    final items = _reminders
        .where((reminder) => !reminder.isCompleted && reminder.isNote)
        .toList();
    items.sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return items;
  }

  List<Reminder> get pendingScheduledReminders {
    final items = _reminders
        .where((reminder) => !reminder.isCompleted && reminder.hasSchedule)
        .toList();
    items.sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));
    return items;
  }

  List<Reminder> get completedReminders {
    final items = _reminders.where((reminder) => reminder.isCompleted).toList();
    items.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return items;
  }

  Reminder? get nextReminder {
    final items = _reminders
        .where((reminder) => reminder.shouldNotify)
        .toList();
    if (items.isEmpty) {
      return null;
    }
    items.sort(
      (left, right) => left.notificationAt.compareTo(right.notificationAt),
    );
    return items.first;
  }

  Reminder? findReminderById(int reminderId) {
    for (final reminder in _reminders) {
      if (reminder.id == reminderId) {
        return reminder;
      }
    }
    return null;
  }

  Future<void> initialize() async {
    await _refresh(syncNotifications: true);
  }

  Future<void> refresh() async {
    await _refresh(syncNotifications: true);
  }

  Future<void> requestPermissionsIfNeeded() async {
    if (_permissionsRequested) {
      return;
    }

    _permissionsRequested = true;
    await _notificationService.requestPermissions();
  }

  void requestReminderOpen(int reminderId) {
    _pendingReminderOpenId = reminderId;
    _pendingReminderOpenRequest += 1;
    notifyListeners();
  }

  void clearPendingReminderOpen() {
    if (_pendingReminderOpenId == null) {
      return;
    }
    _pendingReminderOpenId = null;
    notifyListeners();
  }

  Future<void> createReminder({
    required String title,
    required DateTime scheduledAt,
    required int advanceReminderMinutes,
    required ReminderRepeatInterval repeatInterval,
    ReminderRepeatSettings repeatSettings = const ReminderRepeatSettings(),
    ReminderKind kind = ReminderKind.reminder,
    bool hasSchedule = true,
  }) async {
    final now = DateTime.now();
    final isUnscheduledKind = _isUnscheduledKind(kind);
    final cleanTitle = polishVoiceTitleText(title);
    final effectiveRepeatInterval = isUnscheduledKind
        ? ReminderRepeatInterval.none
        : repeatInterval;
    final reminder = Reminder(
      title: cleanTitle.isEmpty ? title.trim() : cleanTitle,
      scheduledAt: scheduledAt,
      advanceReminderMinutes: isUnscheduledKind ? 0 : advanceReminderMinutes,
      repeatInterval: effectiveRepeatInterval,
      repeatSettings: repeatSettings.normalizedForInterval(
        effectiveRepeatInterval,
      ),
      isCompleted: false,
      createdAt: now,
      updatedAt: now,
      kind: kind,
      hasSchedule: isUnscheduledKind ? false : hasSchedule,
    );

    final storedReminder = await _runMutation<Reminder>(
      'No se pudo guardar el recordatorio.',
      () => _repository.insert(reminder),
    );

    _upsertReminder(storedReminder);
    await _notificationService.syncReminders(_reminders);
    notifyListeners();
  }

  Future<void> createTask({required String title}) async {
    final now = DateTime.now();
    await createReminder(
      title: title,
      scheduledAt: now,
      advanceReminderMinutes: 0,
      repeatInterval: ReminderRepeatInterval.none,
      kind: ReminderKind.task,
      hasSchedule: false,
    );
  }

  Future<void> createShoppingListItem({required String title}) async {
    final now = DateTime.now();
    await createReminder(
      title: title,
      scheduledAt: now,
      advanceReminderMinutes: 0,
      repeatInterval: ReminderRepeatInterval.none,
      kind: ReminderKind.shoppingList,
      hasSchedule: false,
    );
  }

  Future<void> createNote({required String title}) async {
    final now = DateTime.now();
    await createReminder(
      title: title,
      scheduledAt: now,
      advanceReminderMinutes: 0,
      repeatInterval: ReminderRepeatInterval.none,
      kind: ReminderKind.note,
      hasSchedule: false,
    );
  }

  Future<void> updateReminder(
    Reminder reminder, {
    required String title,
    required DateTime scheduledAt,
    required int advanceReminderMinutes,
    required ReminderRepeatInterval repeatInterval,
    ReminderRepeatSettings repeatSettings = const ReminderRepeatSettings(),
    ReminderKind? kind,
    bool? hasSchedule,
  }) async {
    final nextKind = kind ?? reminder.kind;
    final isUnscheduledKind = _isUnscheduledKind(nextKind);
    final cleanTitle = polishVoiceTitleText(title);
    final updatedReminder = reminder.copyWith(
      title: cleanTitle.isEmpty ? title.trim() : cleanTitle,
      scheduledAt: scheduledAt,
      advanceReminderMinutes: isUnscheduledKind ? 0 : advanceReminderMinutes,
      repeatInterval: isUnscheduledKind
          ? ReminderRepeatInterval.none
          : repeatInterval,
      repeatSettings: repeatSettings,
      kind: nextKind,
      hasSchedule: isUnscheduledKind ? false : hasSchedule ?? true,
      snoozedUntil: null,
      updatedAt: DateTime.now(),
    );

    final storedReminder = await _runMutation<Reminder>(
      'No se pudo actualizar el recordatorio.',
      () => _repository.update(updatedReminder),
    );

    _upsertReminder(storedReminder);
    await _notificationService.syncReminders(_reminders);
    notifyListeners();
  }

  Future<void> setCompleted(Reminder reminder, bool isCompleted) async {
    if (isCompleted && reminder.hasSchedule && reminder.isRepeating) {
      final updatedReminder = reminder.copyWith(
        scheduledAt: nextReminderOccurrence(
          reminder.scheduledAt,
          reminder.repeatInterval,
          repeatSettings: reminder.repeatSettings,
        ),
        isCompleted: false,
        snoozedUntil: null,
        updatedAt: DateTime.now(),
      );

      final storedReminder = await _runMutation<Reminder>(
        'No se pudo completar la repeticion del recordatorio.',
        () => _repository.update(updatedReminder),
      );

      _upsertReminder(storedReminder);
      await _notificationService.syncReminders(_reminders);
      notifyListeners();
      return;
    }

    final updatedReminder = reminder.copyWith(
      isCompleted: isCompleted,
      snoozedUntil: null,
      updatedAt: DateTime.now(),
    );

    final storedReminder = await _runMutation<Reminder>(
      'No se pudo actualizar el estado del recordatorio.',
      () => _repository.update(updatedReminder),
    );

    _upsertReminder(storedReminder);
    await _notificationService.syncReminders(_reminders);
    notifyListeners();
  }

  Future<void> snoozeReminder(
    Reminder reminder, {
    Duration duration = defaultReminderSnoozeDuration,
  }) async {
    final snoozedUntil = DateTime.now().add(duration);
    final updatedReminder = reminder.copyWith(
      isCompleted: false,
      snoozedUntil: snoozedUntil,
      updatedAt: DateTime.now(),
    );

    final storedReminder = await _runMutation<Reminder>(
      'No se pudo posponer el recordatorio.',
      () => _repository.update(updatedReminder),
    );

    _upsertReminder(storedReminder);
    await _notificationService.syncReminders(_reminders);
    notifyListeners();
  }

  Future<void> deleteReminder(Reminder reminder) async {
    final reminderId = reminder.id;
    if (reminderId == null) {
      return;
    }

    await _runMutation<void>(
      'No se pudo eliminar el recordatorio.',
      () => _repository.delete(reminderId),
    );

    _reminders.removeWhere((item) => item.id == reminderId);
    await _notificationService.syncReminders(_reminders);
    notifyListeners();
  }

  Future<void> _refresh({required bool syncNotifications}) async {
    try {
      final storedReminders = await _repository.fetchAll();
      _replaceReminders(storedReminders);
      if (syncNotifications) {
        await _notificationService.syncReminders(_reminders);
      }
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'No se pudieron cargar los recordatorios.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<T> _runMutation<T>(
    String fallbackMessage,
    Future<T> Function() action,
  ) async {
    try {
      final result = await action();
      _errorMessage = null;
      return result;
    } catch (_, stackTrace) {
      _errorMessage = fallbackMessage;
      notifyListeners();
      Error.throwWithStackTrace(StateError(fallbackMessage), stackTrace);
    }
  }

  void _replaceReminders(List<Reminder> reminders) {
    _reminders
      ..clear()
      ..addAll(reminders);
    _sortReminders();
  }

  void _upsertReminder(Reminder reminder) {
    final index = _reminders.indexWhere((item) => item.id == reminder.id);
    if (index == -1) {
      _reminders.add(reminder);
    } else {
      _reminders[index] = reminder;
    }
    _sortReminders();
  }

  void _sortReminders() {
    _reminders.sort((left, right) {
      if (left.isCompleted != right.isCompleted) {
        return left.isCompleted ? 1 : -1;
      }
      if (left.isCompleted && right.isCompleted) {
        return right.updatedAt.compareTo(left.updatedAt);
      }
      return left.scheduledAt.compareTo(right.scheduledAt);
    });
  }
}

bool _isUnscheduledKind(ReminderKind kind) {
  return kind == ReminderKind.task ||
      kind == ReminderKind.shoppingList ||
      kind == ReminderKind.note;
}

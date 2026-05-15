import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/reminder_repository.dart';
import '../models/reminder.dart';
import '../utils/voice_text_polisher.dart';

const String _channelId = 'recordatorio_alertas_v2';
const String _channelName = 'Recordatorios con sonido';
const String _channelDescription =
    'Avisos programados para los recordatorios guardados en la app.';
const String _voiceShortcutChannelId = 'recordatorio_acceso_voz';
const String _voiceShortcutChannelName = 'Tareas en pantalla bloqueada';
const String _voiceShortcutChannelDescription =
    'Panel fijo de tareas y acceso rapido desde la pantalla bloqueada.';
const List<String> _legacyChannelIds = <String>['recordatorio_channel'];
const String _snooze10ActionId = 'snooze_10m';
const String _snooze30ActionId = 'snooze_30m';
const String _snooze60ActionId = 'snooze_60m';
const String _completeActionId = 'complete_reminder';
const Duration _defaultNotificationSnoozeDuration = Duration(minutes: 10);
const Duration _extendedNotificationSnoozeDuration = Duration(minutes: 30);
const Duration _longNotificationSnoozeDuration = Duration(hours: 1);
const int _voiceShortcutNotificationId = 2147482999;
const int _lockScreenMaxCollapsedItems = 3;

@pragma('vm:entry-point')
Future<void> reminderNotificationTapBackground(
  NotificationResponse notificationResponse,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await _processReminderNotificationResponse(notificationResponse);
}

abstract interface class ReminderNotificationService {
  Future<void> initialize();
  Future<void> requestPermissions();
  Future<void> scheduleReminder(Reminder reminder);
  Future<void> cancelReminder(int reminderId);
  Future<void> syncReminders(Iterable<Reminder> reminders);
}

class LocalReminderNotificationService implements ReminderNotificationService {
  LocalReminderNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final DateFormat _dateFormat = DateFormat("EEE d MMM 'a las' HH:mm", 'es_ES');

  bool _initialized = false;
  bool _exactAlarmsAllowed = true;
  List<Reminder> _lastKnownReminders = <Reminder>[];
  Future<void> Function()? _onReminderChanged;
  void Function(int reminderId)? _onOpenReminderRequested;
  int? _pendingReminderIdToOpen;

  void setOnReminderChangedCallback(Future<void> Function() callback) {
    _onReminderChanged = callback;
  }

  void setOnOpenReminderRequestedCallback(
    void Function(int reminderId) callback,
  ) {
    _onOpenReminderRequested = callback;
    final pendingReminderId = _pendingReminderIdToOpen;
    if (pendingReminderId == null) {
      return;
    }

    _pendingReminderIdToOpen = null;
    callback(pendingReminderId);
  }

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz_data.initializeTimeZones();
    await _configureLocalTimeZone();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          reminderNotificationTapBackground,
    );
    await _captureNotificationLaunchDetails();

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final channelId in _legacyChannelIds) {
      await androidPlugin?.deleteNotificationChannel(channelId: channelId);
    }
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _voiceShortcutChannelId,
        _voiceShortcutChannelName,
        description: _voiceShortcutChannelDescription,
        importance: Importance.defaultImportance,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );

    _initialized = true;
    await _showVoiceShortcutNotification(_lastKnownReminders);
  }

  @override
  Future<void> requestPermissions() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    try {
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestFullScreenIntentPermission();
      final exactAlarmsGranted = await androidPlugin
          ?.requestExactAlarmsPermission();
      _exactAlarmsAllowed = exactAlarmsGranted ?? true;
    } catch (_) {
      _exactAlarmsAllowed = false;
    }
    await _showVoiceShortcutNotification(_lastKnownReminders);
  }

  @override
  Future<void> scheduleReminder(Reminder reminder) async {
    final reminderId = reminder.id;
    if (reminderId == null) {
      return;
    }

    if (!reminder.shouldNotify) {
      await cancelReminder(reminderId);
      return;
    }

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        ticker: 'Recordatorio',
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(_snooze10ActionId, 'Posponer 10 min'),
          AndroidNotificationAction(_snooze30ActionId, 'Posponer 30 min'),
          AndroidNotificationAction(_snooze60ActionId, 'Posponer 1 hora'),
          AndroidNotificationAction(_completeActionId, 'Completado'),
        ],
      ),
    );

    await _scheduleNotification(
      id: reminderId,
      title: reminder.title,
      body: _buildReminderNotificationBody(reminder),
      scheduledAt: reminder.notificationAt,
      details: notificationDetails,
    );
  }

  @override
  Future<void> cancelReminder(int reminderId) async {
    try {
      await _plugin.cancel(id: reminderId);
    } catch (_) {}
  }

  @override
  Future<void> syncReminders(Iterable<Reminder> reminders) async {
    _lastKnownReminders = reminders.toList();
    final activeReminderIds = reminders
        .where((reminder) => reminder.shouldNotify && reminder.id != null)
        .map((reminder) => reminder.id!)
        .toSet();
    final activeIds = <int>{...activeReminderIds};

    try {
      final pendingRequests = await _plugin.pendingNotificationRequests();
      for (final pendingRequest in pendingRequests) {
        if (!activeIds.contains(pendingRequest.id)) {
          await _plugin.cancel(id: pendingRequest.id);
        }
      }
    } catch (_) {}

    for (final reminder in reminders.where((item) => item.shouldNotify)) {
      await scheduleReminder(reminder);
    }
    await _showVoiceShortcutNotification(_lastKnownReminders);
  }

  Future<void> _configureLocalTimeZone() async {
    try {
      final localTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimeZone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<void> _onDidReceiveNotificationResponse(
    NotificationResponse notificationResponse,
  ) async {
    final didChange = await _processReminderNotificationResponse(
      notificationResponse,
    );
    if (didChange) {
      await _onReminderChanged?.call();
      return;
    }

    _queueReminderOpenFromResponse(notificationResponse);
  }

  Future<void> _showVoiceShortcutNotification(
    Iterable<Reminder> reminders,
  ) async {
    final today = DateTime.now();
    final agendaDate = DateTime(today.year, today.month, today.day);
    final itineraryItemCount = _buildLockScreenPreviewItems(
      reminders,
      agendaDate,
    ).length;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _voiceShortcutChannelId,
        _voiceShortcutChannelName,
        channelDescription: _voiceShortcutChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: false,
        enableVibration: false,
        autoCancel: false,
        ongoing: true,
        silent: true,
        onlyAlertOnce: true,
        showWhen: false,
        channelShowBadge: false,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
        styleInformation: BigTextStyleInformation(
          buildLockScreenItineraryExpandedBody(reminders, agendaDate),
          contentTitle: 'Itinerario de hoy',
          summaryText: _buildItinerarySummaryText(itineraryItemCount),
        ),
        ticker: 'Itinerario de hoy',
      ),
    );

    try {
      await _plugin.show(
        id: _voiceShortcutNotificationId,
        title: 'Itinerario de hoy',
        body: buildLockScreenTaskBody(reminders),
        notificationDetails: details,
      );
    } catch (_) {}
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required NotificationDetails details,
  }) async {
    final scheduledDate = tz.TZDateTime.from(scheduledAt, tz.local);

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: _exactAlarmsAllowed
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: id.toString(),
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: id.toString(),
        );
      } catch (_) {}
    }
  }

  String _buildReminderNotificationBody(Reminder reminder) {
    if (reminder.isSnoozed) {
      return 'Pospuesto hasta ${_dateFormat.format(reminder.notificationAt)}';
    }
    if (!reminder.hasAdvanceReminder) {
      if (reminder.isRepeating) {
        return 'Programado para ${_dateFormat.format(reminder.scheduledAt)}. ${describeRepeatReminder(reminder.repeatInterval, repeatSettings: reminder.repeatSettings)}.';
      }
      return 'Programado para ${_dateFormat.format(reminder.scheduledAt)}';
    }
    return 'Aviso ${formatAdvanceReminderLabel(reminder.advanceReminderMinutes)}. Evento previsto para ${_dateFormat.format(reminder.scheduledAt)}${reminder.isRepeating ? '. ${describeRepeatReminder(reminder.repeatInterval, repeatSettings: reminder.repeatSettings)}.' : ''}';
  }

  Future<void> _captureNotificationLaunchDetails() async {
    try {
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        _queueReminderOpenFromResponse(launchDetails?.notificationResponse);
      }
    } catch (_) {}
  }

  void _queueReminderOpenFromResponse(NotificationResponse? response) {
    final reminderId = reminderIdToOpenFromNotificationTap(
      openedFromNotificationBody:
          response?.notificationResponseType ==
          NotificationResponseType.selectedNotification,
      notificationId: response?.id,
      payload: response?.payload,
    );
    if (reminderId == null) {
      return;
    }

    final callback = _onOpenReminderRequested;
    if (callback != null) {
      callback(reminderId);
      return;
    }

    _pendingReminderIdToOpen = reminderId;
  }
}

@visibleForTesting
DateTime nextDailyAgendaNotificationTime(DateTime now, {int hour = 8}) {
  var candidate = DateTime(now.year, now.month, now.day, hour);
  if (!candidate.isAfter(now)) {
    candidate = candidate.add(const Duration(days: 1));
  }
  return candidate;
}

@visibleForTesting
DateTime agendaDateForNotificationTime(DateTime scheduledAt) {
  return DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
}

@visibleForTesting
String buildLockScreenTaskBody(Iterable<Reminder> reminders) {
  final now = DateTime.now();
  final agendaDate = DateTime(now.year, now.month, now.day);
  final previewItems = _buildLockScreenPreviewItems(reminders, agendaDate);

  if (previewItems.isEmpty) {
    return 'No hay tareas ni recordatorios pendientes. Toca para crear uno por voz.';
  }

  final previews = previewItems.take(_lockScreenMaxCollapsedItems).toList();
  if (previewItems.length == 1) {
    return '1 punto pendiente: ${previews.first}.';
  }

  if (previewItems.length <= _lockScreenMaxCollapsedItems) {
    return '${previewItems.length} puntos pendientes: ${previews.join(', ')}.';
  }

  final remaining = previewItems.length - previews.length;
  return '${previewItems.length} puntos pendientes: ${previews.join(', ')} y $remaining mas.';
}

@visibleForTesting
List<String> buildLockScreenItineraryLines(
  Iterable<Reminder> reminders,
  DateTime agendaDate,
) {
  final tasks =
      reminders
          .where((reminder) => !reminder.isCompleted && reminder.isTask)
          .toList()
        ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
  final scheduledReminders =
      reminders
          .where(
            (reminder) =>
                !reminder.isCompleted &&
                reminder.hasSchedule &&
                reminder.scheduledAt.year == agendaDate.year &&
                reminder.scheduledAt.month == agendaDate.month &&
                reminder.scheduledAt.day == agendaDate.day,
          )
          .toList()
        ..sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));

  final timeFormat = DateFormat('HH:mm', 'es_ES');
  final lines = <String>[];

  if (scheduledReminders.isNotEmpty) {
    lines.add('Recordatorios con hora');
    for (final reminder in scheduledReminders) {
      lines.add(
        '${timeFormat.format(reminder.scheduledAt)} - ${formatReadableReminderTitle(reminder.title)}',
      );
    }
  }

  if (tasks.isNotEmpty) {
    if (lines.isNotEmpty) {
      lines.add('');
    }
    lines.add('Tareas pendientes');
    for (var index = 0; index < tasks.length; index += 1) {
      lines.add(
        '${index + 1}. ${formatReadableReminderTitle(tasks[index].title)}',
      );
    }
  }

  return lines;
}

@visibleForTesting
String buildLockScreenItineraryExpandedBody(
  Iterable<Reminder> reminders,
  DateTime agendaDate,
) {
  final lines = buildLockScreenItineraryLines(reminders, agendaDate);
  if (lines.isEmpty) {
    return 'No hay tareas ni recordatorios pendientes para hoy. Puedes crear uno por voz desde el boton lateral.';
  }

  return lines.join('\n');
}

@visibleForTesting
String buildDailyAgendaExpandedBody(
  Iterable<Reminder> reminders,
  DateTime agendaDate,
) {
  final lines = _buildDailyAgendaExpandedLines(reminders, agendaDate);
  if (lines.isEmpty) {
    return 'No hay tareas ni recordatorios pendientes para hoy. Puedes crear uno por voz desde el boton lateral.';
  }

  return lines.join('\n');
}

@visibleForTesting
String buildDailyAgendaNotificationBody(
  Iterable<Reminder> reminders,
  DateTime agendaDate,
) {
  final remindersForDay =
      reminders
          .where(
            (reminder) =>
                !reminder.isCompleted &&
                reminder.hasSchedule &&
                reminder.scheduledAt.year == agendaDate.year &&
                reminder.scheduledAt.month == agendaDate.month &&
                reminder.scheduledAt.day == agendaDate.day,
          )
          .toList()
        ..sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));
  final tasksForDay =
      reminders
          .where((reminder) => !reminder.isCompleted && reminder.isTask)
          .toList()
        ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
  final shoppingItems =
      reminders
          .where(
            (reminder) => !reminder.isCompleted && reminder.isShoppingListItem,
          )
          .toList()
        ..sort((left, right) => left.createdAt.compareTo(right.createdAt));

  if (remindersForDay.isEmpty && tasksForDay.isEmpty && shoppingItems.isEmpty) {
    return 'Hoy no tienes tareas ni recordatorios pendientes.';
  }

  final timeFormat = DateFormat('HH:mm', 'es_ES');
  final previews = <String>[
    ...remindersForDay.map(
      (reminder) =>
          '${timeFormat.format(reminder.scheduledAt)} ${reminder.title}',
    ),
    ...tasksForDay.map((task) => 'Tarea: ${task.title}'),
    ...shoppingItems.map((item) => 'Compra: ${item.title}'),
  ].take(3).toList();
  final totalItems =
      remindersForDay.length + tasksForDay.length + shoppingItems.length;

  if (totalItems == 1) {
    return 'Tu agenda de hoy empieza con ${previews.first}.';
  }

  if (totalItems <= 3) {
    return 'Tu agenda de hoy: ${previews.join(', ')}.';
  }

  final remaining = totalItems - previews.length;
  return 'Tu agenda de hoy: ${previews.join(', ')} y $remaining mas.';
}

List<String> _buildLockScreenPreviewItems(
  Iterable<Reminder> reminders,
  DateTime agendaDate,
) {
  final tasks =
      reminders
          .where((reminder) => !reminder.isCompleted && reminder.isTask)
          .toList()
        ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
  final scheduledReminders =
      reminders
          .where(
            (reminder) =>
                !reminder.isCompleted &&
                reminder.hasSchedule &&
                reminder.scheduledAt.year == agendaDate.year &&
                reminder.scheduledAt.month == agendaDate.month &&
                reminder.scheduledAt.day == agendaDate.day,
          )
          .toList()
        ..sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));

  final timeFormat = DateFormat('HH:mm', 'es_ES');
  return <String>[
    ...scheduledReminders.map(
      (reminder) =>
          '${timeFormat.format(reminder.scheduledAt)} ${reminder.title}',
    ),
    ...tasks.map((task) => 'Tarea: ${task.title}'),
  ];
}

List<String> _buildDailyAgendaExpandedLines(
  Iterable<Reminder> reminders,
  DateTime agendaDate,
) {
  final tasks =
      reminders
          .where((reminder) => !reminder.isCompleted && reminder.isTask)
          .toList()
        ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
  final shoppingItems =
      reminders
          .where(
            (reminder) => !reminder.isCompleted && reminder.isShoppingListItem,
          )
          .toList()
        ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
  final scheduledReminders =
      reminders
          .where(
            (reminder) =>
                !reminder.isCompleted &&
                reminder.hasSchedule &&
                reminder.scheduledAt.year == agendaDate.year &&
                reminder.scheduledAt.month == agendaDate.month &&
                reminder.scheduledAt.day == agendaDate.day,
          )
          .toList()
        ..sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));

  final timeFormat = DateFormat('HH:mm', 'es_ES');
  final lines = <String>[];

  if (scheduledReminders.isNotEmpty) {
    lines.add('Recordatorios con hora');
    for (final reminder in scheduledReminders) {
      lines.add(
        '${timeFormat.format(reminder.scheduledAt)} - ${formatReadableReminderTitle(reminder.title)}',
      );
    }
  }

  if (tasks.isNotEmpty) {
    if (lines.isNotEmpty) {
      lines.add('');
    }
    lines.add('Tareas pendientes');
    for (var index = 0; index < tasks.length; index += 1) {
      lines.add(
        '${index + 1}. ${formatReadableReminderTitle(tasks[index].title)}',
      );
    }
  }

  if (shoppingItems.isNotEmpty) {
    if (lines.isNotEmpty) {
      lines.add('');
    }
    lines.add('Lista de la compra');
    for (var index = 0; index < shoppingItems.length; index += 1) {
      lines.add(
        '${index + 1}. ${formatReadableReminderTitle(shoppingItems[index].title)}',
      );
    }
  }

  return lines;
}

String _buildItinerarySummaryText(int itemCount) {
  if (itemCount == 0) {
    return 'Sin pendientes';
  }
  if (itemCount == 1) {
    return '1 punto visible';
  }
  return '$itemCount puntos visibles';
}

@visibleForTesting
int? reminderIdToOpenFromNotificationTap({
  required bool openedFromNotificationBody,
  int? notificationId,
  String? payload,
}) {
  if (!openedFromNotificationBody) {
    return null;
  }

  final parsedPayload = int.tryParse(payload?.trim() ?? '');
  final resolvedNotificationId = notificationId ?? parsedPayload;
  if (resolvedNotificationId == null ||
      resolvedNotificationId == _voiceShortcutNotificationId) {
    return null;
  }
  return resolvedNotificationId;
}

Future<bool> _processReminderNotificationResponse(
  NotificationResponse notificationResponse,
) async {
  final reminderId = notificationResponse.id;
  if (reminderId == null) {
    return false;
  }

  switch (notificationResponse.actionId) {
    case _completeActionId:
      return _completeReminderFromNotification(reminderId);
    case _snooze10ActionId:
      return _snoozeReminderFromNotification(
        reminderId,
        duration: _defaultNotificationSnoozeDuration,
      );
    case _snooze30ActionId:
      return _snoozeReminderFromNotification(
        reminderId,
        duration: _extendedNotificationSnoozeDuration,
      );
    case _snooze60ActionId:
      return _snoozeReminderFromNotification(
        reminderId,
        duration: _longNotificationSnoozeDuration,
      );
    default:
      return false;
  }
}

Future<bool> _completeReminderFromNotification(int reminderId) async {
  final repository = SqfliteReminderRepository();
  await repository.initialize();

  final reminder = await repository.fetchById(reminderId);
  if (reminder == null) {
    return false;
  }

  if (reminder.hasSchedule && reminder.isRepeating) {
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
    await repository.update(updatedReminder);
  } else {
    final updatedReminder = reminder.copyWith(
      isCompleted: true,
      snoozedUntil: null,
      updatedAt: DateTime.now(),
    );
    await repository.update(updatedReminder);
  }

  final notificationService = LocalReminderNotificationService();
  await notificationService.initialize();
  await notificationService.syncReminders(await repository.fetchAll());
  return true;
}

Future<bool> _snoozeReminderFromNotification(
  int reminderId, {
  required Duration duration,
}) async {
  final repository = SqfliteReminderRepository();
  await repository.initialize();

  final reminder = await repository.fetchById(reminderId);
  if (reminder == null) {
    return false;
  }

  final updatedReminder = reminder.copyWith(
    isCompleted: false,
    snoozedUntil: DateTime.now().add(duration),
    updatedAt: DateTime.now(),
  );
  await repository.update(updatedReminder);

  final notificationService = LocalReminderNotificationService();
  await notificationService.initialize();
  await notificationService.syncReminders(await repository.fetchAll());
  return true;
}

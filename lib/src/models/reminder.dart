import 'package:flutter/foundation.dart';

const Object _undefined = Object();

enum ReminderRepeatInterval {
  none('none', 'No repetir'),
  daily('daily', 'Cada dia'),
  weekly('weekly', 'Cada semana'),
  monthly('monthly', 'Cada mes');

  const ReminderRepeatInterval(this.key, this.label);

  final String key;
  final String label;

  bool get isRepeating => this != ReminderRepeatInterval.none;

  static ReminderRepeatInterval fromKey(String? key) {
    return ReminderRepeatInterval.values.firstWhere(
      (interval) => interval.key == key,
      orElse: () => ReminderRepeatInterval.none,
    );
  }
}

enum ReminderKind {
  reminder('reminder', 'Recordatorio'),
  task('task', 'Tarea'),
  shoppingList('shopping_list', 'Lista de la Compra'),
  note('note', 'Nota');

  const ReminderKind(this.key, this.label);

  final String key;
  final String label;

  static ReminderKind fromKey(String? key) {
    return ReminderKind.values.firstWhere(
      (kind) => kind.key == key,
      orElse: () => ReminderKind.reminder,
    );
  }
}

bool _kindHasNoSchedule(ReminderKind kind) {
  return kind == ReminderKind.task ||
      kind == ReminderKind.shoppingList ||
      kind == ReminderKind.note;
}

const int defaultScheduledAdvanceReminderMinutes = 30;

int defaultAdvanceReminderMinutesForKind({
  ReminderKind kind = ReminderKind.reminder,
  bool hasSchedule = true,
}) {
  if (!hasSchedule || _kindHasNoSchedule(kind)) {
    return 0;
  }
  return defaultScheduledAdvanceReminderMinutes;
}

@immutable
class ReminderRepeatSettings {
  const ReminderRepeatSettings({
    this.monthDay,
    this.monthWeekOfMonth,
    this.monthWeekFromEnd,
    this.monthWeekday,
    this.monthUsesLastDay = false,
  });

  final int? monthDay;
  final int? monthWeekOfMonth;
  final int? monthWeekFromEnd;
  final int? monthWeekday;
  final bool monthUsesLastDay;

  bool get hasMonthWeekdayPattern =>
      monthWeekday != null &&
      (monthWeekOfMonth != null || monthWeekFromEnd != null);

  bool get hasMonthlyPattern =>
      monthUsesLastDay || monthDay != null || hasMonthWeekdayPattern;

  ReminderRepeatSettings copyWith({
    Object? monthDay = _undefined,
    Object? monthWeekOfMonth = _undefined,
    Object? monthWeekFromEnd = _undefined,
    Object? monthWeekday = _undefined,
    bool? monthUsesLastDay,
  }) {
    return ReminderRepeatSettings(
      monthDay: identical(monthDay, _undefined)
          ? this.monthDay
          : monthDay as int?,
      monthWeekOfMonth: identical(monthWeekOfMonth, _undefined)
          ? this.monthWeekOfMonth
          : monthWeekOfMonth as int?,
      monthWeekFromEnd: identical(monthWeekFromEnd, _undefined)
          ? this.monthWeekFromEnd
          : monthWeekFromEnd as int?,
      monthWeekday: identical(monthWeekday, _undefined)
          ? this.monthWeekday
          : monthWeekday as int?,
      monthUsesLastDay: monthUsesLastDay ?? this.monthUsesLastDay,
    );
  }

  ReminderRepeatSettings normalizedForInterval(
    ReminderRepeatInterval repeatInterval,
  ) {
    if (repeatInterval == ReminderRepeatInterval.monthly) {
      return this;
    }
    return const ReminderRepeatSettings();
  }
}

int normalizeAdvanceReminderMinutes(int minutes) {
  if (minutes < 0) {
    return 0;
  }
  return minutes;
}

Duration advanceReminderDuration(int minutes) {
  return Duration(minutes: normalizeAdvanceReminderMinutes(minutes));
}

String formatAdvanceReminderLabel(int minutes) {
  final normalizedMinutes = normalizeAdvanceReminderMinutes(minutes);
  if (normalizedMinutes == 0) {
    return 'a la hora exacta';
  }
  if (normalizedMinutes == 1) {
    return '1 minuto antes';
  }
  return '$normalizedMinutes minutos antes';
}

String describeAdvanceReminder(int minutes) {
  final normalizedMinutes = normalizeAdvanceReminderMinutes(minutes);
  if (normalizedMinutes == 0) {
    return 'La notificacion llegara a la hora elegida.';
  }
  if (normalizedMinutes == 1) {
    return 'La notificacion llegara un minuto antes del recordatorio.';
  }
  return 'La notificacion llegara $normalizedMinutes minutos antes del recordatorio.';
}

DateTime nextReminderOccurrence(
  DateTime from,
  ReminderRepeatInterval repeatInterval, {
  ReminderRepeatSettings repeatSettings = const ReminderRepeatSettings(),
}) {
  switch (repeatInterval) {
    case ReminderRepeatInterval.none:
      return from;
    case ReminderRepeatInterval.daily:
      return from.add(const Duration(days: 1));
    case ReminderRepeatInterval.weekly:
      return from.add(const Duration(days: 7));
    case ReminderRepeatInterval.monthly:
      return _nextMonthlyOccurrence(from, repeatSettings);
  }
}

String describeRepeatReminder(
  ReminderRepeatInterval repeatInterval, {
  ReminderRepeatSettings repeatSettings = const ReminderRepeatSettings(),
}) {
  return switch (repeatInterval) {
    ReminderRepeatInterval.none => 'Sin repeticion',
    ReminderRepeatInterval.daily => 'Repite cada dia',
    ReminderRepeatInterval.weekly => 'Repite cada semana',
    ReminderRepeatInterval.monthly => _describeMonthlyRepeatReminder(
      repeatSettings,
    ),
  };
}

@immutable
class Reminder {
  const Reminder({
    this.id,
    required this.title,
    required this.scheduledAt,
    required this.advanceReminderMinutes,
    required this.repeatInterval,
    this.repeatSettings = const ReminderRepeatSettings(),
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
    this.kind = ReminderKind.reminder,
    this.hasSchedule = true,
    this.snoozedUntil,
  });

  final int? id;
  final String title;
  final DateTime scheduledAt;
  final int advanceReminderMinutes;
  final ReminderRepeatInterval repeatInterval;
  final ReminderRepeatSettings repeatSettings;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ReminderKind kind;
  final bool hasSchedule;
  final DateTime? snoozedUntil;

  bool get isShoppingListItem => kind == ReminderKind.shoppingList;
  bool get isNote => kind == ReminderKind.note;
  bool get isTask =>
      kind == ReminderKind.task ||
      (kind == ReminderKind.reminder && !hasSchedule);
  bool get isOverdue =>
      hasSchedule && !isCompleted && scheduledAt.isBefore(DateTime.now());
  bool get isSnoozed =>
      hasSchedule &&
      !isCompleted &&
      snoozedUntil != null &&
      snoozedUntil!.isAfter(DateTime.now());
  bool get hasAdvanceReminder => advanceReminderMinutes > 0;
  bool get isRepeating => repeatInterval.isRepeating;
  Duration get advanceDuration =>
      advanceReminderDuration(advanceReminderMinutes);
  DateTime get baseNotificationAt => scheduledAt.subtract(advanceDuration);
  DateTime get notificationAt {
    final snoozedUntil = this.snoozedUntil;
    if (snoozedUntil != null && snoozedUntil.isAfter(DateTime.now())) {
      return snoozedUntil;
    }
    return baseNotificationAt;
  }

  bool get shouldNotify =>
      hasSchedule && !isCompleted && notificationAt.isAfter(DateTime.now());

  Reminder copyWith({
    Object? id = _undefined,
    String? title,
    DateTime? scheduledAt,
    Object? advanceReminderMinutes = _undefined,
    ReminderRepeatInterval? repeatInterval,
    ReminderRepeatSettings? repeatSettings,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    ReminderKind? kind,
    bool? hasSchedule,
    Object? snoozedUntil = _undefined,
  }) {
    final nextKind = kind ?? this.kind;
    final defaultHasSchedule = nextKind == this.kind
        ? this.hasSchedule
        : nextKind == ReminderKind.reminder;
    final nextHasSchedule = _kindHasNoSchedule(nextKind)
        ? false
        : hasSchedule ?? defaultHasSchedule;
    final nextRepeatInterval = repeatInterval ?? this.repeatInterval;
    final nextRepeatSettings = (repeatSettings ?? this.repeatSettings)
        .normalizedForInterval(nextRepeatInterval);

    return Reminder(
      id: identical(id, _undefined) ? this.id : id as int?,
      title: title ?? this.title,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      advanceReminderMinutes: identical(advanceReminderMinutes, _undefined)
          ? this.advanceReminderMinutes
          : advanceReminderMinutes as int,
      repeatInterval: nextRepeatInterval,
      repeatSettings: nextRepeatSettings,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      kind: nextKind,
      hasSchedule: nextHasSchedule,
      snoozedUntil: identical(snoozedUntil, _undefined)
          ? this.snoozedUntil
          : snoozedUntil as DateTime?,
    );
  }

  Map<String, Object?> toMap() {
    final normalizedRepeatSettings = repeatSettings.normalizedForInterval(
      repeatInterval,
    );
    return <String, Object?>{
      'id': id,
      'title': title,
      'scheduled_at': scheduledAt.toIso8601String(),
      'advance_minutes': advanceReminderMinutes,
      'repeat_interval': repeatInterval.key,
      'repeat_month_day': normalizedRepeatSettings.monthDay,
      'repeat_month_week': normalizedRepeatSettings.monthWeekOfMonth,
      'repeat_month_week_from_end': normalizedRepeatSettings.monthWeekFromEnd,
      'repeat_month_weekday': normalizedRepeatSettings.monthWeekday,
      'repeat_month_last_day': normalizedRepeatSettings.monthUsesLastDay
          ? 1
          : 0,
      'is_completed': isCompleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'kind': kind.key,
      'has_schedule': hasSchedule ? 1 : 0,
      'snoozed_until': snoozedUntil?.toIso8601String(),
    };
  }

  factory Reminder.fromMap(Map<String, Object?> map) {
    final repeatInterval = ReminderRepeatInterval.fromKey(
      map['repeat_interval'] as String?,
    );
    final kind = ReminderKind.fromKey(map['kind'] as String?);
    final rawHasSchedule = map['has_schedule'];
    final parsedHasSchedule = switch (rawHasSchedule) {
      final int value => value == 1,
      _ => kind == ReminderKind.reminder,
    };
    final hasSchedule = _kindHasNoSchedule(kind) ? false : parsedHasSchedule;
    return Reminder(
      id: map['id'] as int?,
      title: map['title'] as String,
      scheduledAt: DateTime.parse(map['scheduled_at'] as String),
      advanceReminderMinutes: normalizeAdvanceReminderMinutes(
        (map['advance_minutes'] as int?) ?? 0,
      ),
      repeatInterval: repeatInterval,
      repeatSettings: ReminderRepeatSettings(
        monthDay: map['repeat_month_day'] as int?,
        monthWeekOfMonth: map['repeat_month_week'] as int?,
        monthWeekFromEnd: map['repeat_month_week_from_end'] as int?,
        monthWeekday: map['repeat_month_weekday'] as int?,
        monthUsesLastDay: ((map['repeat_month_last_day'] as int?) ?? 0) == 1,
      ).normalizedForInterval(repeatInterval),
      isCompleted: (map['is_completed'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      kind: kind,
      hasSchedule: hasSchedule,
      snoozedUntil: switch (map['snoozed_until']) {
        final String value => DateTime.parse(value),
        _ => null,
      },
    );
  }
}

DateTime _nextMonthlyOccurrence(
  DateTime from,
  ReminderRepeatSettings repeatSettings,
) {
  final nextMonth = DateTime(from.year, from.month + 1, 1);
  return _buildMonthlyOccurrence(
    year: nextMonth.year,
    month: nextMonth.month,
    repeatSettings: repeatSettings,
    fallbackDay: from.day,
    source: from,
  );
}

DateTime _buildMonthlyOccurrence({
  required int year,
  required int month,
  required ReminderRepeatSettings repeatSettings,
  required int fallbackDay,
  required DateTime source,
}) {
  final day = switch (repeatSettings.monthUsesLastDay) {
    true => DateTime(year, month + 1, 0).day,
    false when repeatSettings.monthWeekFromEnd != null =>
      _dayForWeekdayFromEndOfMonth(
        year,
        month,
        repeatSettings.monthWeekday!,
        repeatSettings.monthWeekFromEnd!,
      ),
    false when repeatSettings.hasMonthWeekdayPattern => _dayForWeekdayOfMonth(
      year,
      month,
      repeatSettings.monthWeekday!,
      repeatSettings.monthWeekOfMonth!,
    ),
    _ => _safeMonthDay(year, month, repeatSettings.monthDay ?? fallbackDay),
  };

  return DateTime(
    year,
    month,
    day,
    source.hour,
    source.minute,
    source.second,
    source.millisecond,
    source.microsecond,
  );
}

int _safeMonthDay(int year, int month, int requestedDay) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return requestedDay <= lastDay ? requestedDay : lastDay;
}

int _dayForWeekdayOfMonth(int year, int month, int weekday, int weekOfMonth) {
  final firstDay = DateTime(year, month, 1);
  final weekdayOffset = (weekday - firstDay.weekday + 7) % 7;
  var day = 1 + weekdayOffset + ((weekOfMonth - 1) * 7);
  final lastDay = DateTime(year, month + 1, 0).day;
  while (day > lastDay && day > 7) {
    day -= 7;
  }
  return day;
}

int _dayForWeekdayFromEndOfMonth(
  int year,
  int month,
  int weekday,
  int weekFromEnd,
) {
  final lastDay = DateTime(year, month + 1, 0);
  final weekdayOffset = (lastDay.weekday - weekday + 7) % 7;
  var day = lastDay.day - weekdayOffset - ((weekFromEnd - 1) * 7);
  while (day <= 0) {
    day += 7;
  }
  return day;
}

String _describeMonthlyRepeatReminder(ReminderRepeatSettings repeatSettings) {
  if (repeatSettings.monthUsesLastDay) {
    return 'Repite al final de cada mes';
  }
  if (repeatSettings.monthWeekFromEnd != null &&
      repeatSettings.monthWeekday != null) {
    return 'Repite el ${_weekFromEndLabel(repeatSettings.monthWeekFromEnd!)} ${_weekdayLabel(repeatSettings.monthWeekday!)} de cada mes';
  }
  if (repeatSettings.hasMonthWeekdayPattern) {
    return 'Repite el ${_weekOrdinalLabel(repeatSettings.monthWeekOfMonth!)} ${_weekdayLabel(repeatSettings.monthWeekday!)} de cada mes';
  }
  if (repeatSettings.monthDay != null) {
    return 'Repite el dia ${repeatSettings.monthDay} de cada mes';
  }
  return 'Repite cada mes';
}

String _weekOrdinalLabel(int weekOfMonth) {
  return switch (weekOfMonth) {
    1 => 'primer',
    2 => 'segundo',
    3 => 'tercer',
    4 => 'cuarto',
    5 => 'ultimo',
    _ => '$weekOfMonth.',
  };
}

String _weekFromEndLabel(int weekFromEnd) {
  return switch (weekFromEnd) {
    1 => 'ultimo',
    2 => 'penultimo',
    _ => '$weekFromEnd desde el final',
  };
}

String _weekdayLabel(int weekday) {
  return switch (weekday) {
    DateTime.monday => 'lunes',
    DateTime.tuesday => 'martes',
    DateTime.wednesday => 'miercoles',
    DateTime.thursday => 'jueves',
    DateTime.friday => 'viernes',
    DateTime.saturday => 'sabado',
    DateTime.sunday => 'domingo',
    _ => 'dia',
  };
}

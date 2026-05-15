import 'package:flutter/foundation.dart';

import 'reminder.dart';

@immutable
class ReminderDraft {
  const ReminderDraft({
    required this.title,
    required this.scheduledAt,
    required this.advanceReminderMinutes,
    required this.repeatInterval,
    this.repeatSettings = const ReminderRepeatSettings(),
    this.kind = ReminderKind.reminder,
    this.hasSchedule = true,
    this.transcript,
  });

  final String title;
  final DateTime scheduledAt;
  final int advanceReminderMinutes;
  final ReminderRepeatInterval repeatInterval;
  final ReminderRepeatSettings repeatSettings;
  final ReminderKind kind;
  final bool hasSchedule;
  final String? transcript;
}

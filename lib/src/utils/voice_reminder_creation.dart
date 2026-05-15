import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../controllers/reminder_controller.dart';
import '../models/reminder_draft.dart';
import 'voice_reminder_parser.dart';
import 'voice_text_polisher.dart';

ReminderDraft buildReminderDraftFromVoiceTranscript(
  String transcript, {
  DateTime? now,
  VoiceVocabularyMemory? vocabularyMemory,
}) {
  return parseVoiceReminderCommand(
    transcript,
    now: now,
    vocabularyMemory: vocabularyMemory,
  );
}

Future<String> createReminderFromVoiceTranscript(
  BuildContext context,
  String transcript,
) async {
  final controller = context.read<ReminderController>();
  final draft = buildReminderDraftFromVoiceTranscript(
    transcript,
    vocabularyMemory: _memoryFromController(controller),
  );
  await controller.createReminder(
    title: draft.title,
    scheduledAt: draft.scheduledAt,
    advanceReminderMinutes: draft.advanceReminderMinutes,
    repeatInterval: draft.repeatInterval,
    repeatSettings: draft.repeatSettings,
  );
  return draft.title;
}

Future<String> createTaskFromVoiceTranscript(
  BuildContext context,
  String transcript,
) async {
  final controller = context.read<ReminderController>();
  final draft = buildVoiceTaskDraft(transcript);
  await controller.createTask(title: draft.title);
  return draft.title;
}

Future<String> createShoppingListItemFromVoiceTranscript(
  BuildContext context,
  String transcript,
) async {
  final controller = context.read<ReminderController>();
  final draft = buildVoiceShoppingListDraft(transcript);
  await controller.createShoppingListItem(title: draft.title);
  return draft.title;
}

Future<String> createNoteFromVoiceTranscript(
  BuildContext context,
  String transcript,
) async {
  final controller = context.read<ReminderController>();
  final draft = buildVoiceNoteDraft(transcript);
  await controller.createNote(title: draft.title);
  return draft.title;
}

ReminderDraft buildReminderDraftFromVoicePrompts(
  String reminderTranscript,
  String scheduleTranscript, {
  DateTime? now,
  VoiceVocabularyMemory? vocabularyMemory,
}) {
  final title = extractVoiceReminderTitle(
    reminderTranscript,
    now: now,
    vocabularyMemory: vocabularyMemory,
  );
  final combinedTranscript = <String>[
    title,
    scheduleTranscript.trim(),
  ].where((part) => part.isNotEmpty).join(' ');

  return parseVoiceReminderCommand(
    combinedTranscript,
    now: now,
    vocabularyMemory: vocabularyMemory,
  );
}

Future<String> createReminderFromVoicePrompts(
  BuildContext context,
  String reminderTranscript,
  String scheduleTranscript,
) async {
  final controller = context.read<ReminderController>();
  final draft = buildReminderDraftFromVoicePrompts(
    reminderTranscript,
    scheduleTranscript,
    vocabularyMemory: _memoryFromController(controller),
  );
  await controller.createReminder(
    title: draft.title,
    scheduledAt: draft.scheduledAt,
    advanceReminderMinutes: draft.advanceReminderMinutes,
    repeatInterval: draft.repeatInterval,
    repeatSettings: draft.repeatSettings,
  );
  return draft.title;
}

VoiceVocabularyMemory _memoryFromController(ReminderController controller) {
  return VoiceVocabularyMemory.fromTexts(
    controller.reminders.map((reminder) => reminder.title),
  );
}

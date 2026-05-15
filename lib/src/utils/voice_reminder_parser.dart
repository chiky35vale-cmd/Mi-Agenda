import '../models/reminder.dart';
import '../models/reminder_draft.dart';
import 'voice_text_polisher.dart';

const Map<String, int> _weekdays = <String, int>{
  'lunes': DateTime.monday,
  'martes': DateTime.tuesday,
  'miercoles': DateTime.wednesday,
  'jueves': DateTime.thursday,
  'viernes': DateTime.friday,
  'sabado': DateTime.saturday,
  'domingo': DateTime.sunday,
};

const String _fallbackVoiceReminderTitle = 'Recordatorio por voz';
const String _flexibleNumberExpression =
    r'\d{1,4}|(?:cincuenta|cuarenta|treinta|veinte)(?: y (?:nueve|ocho|siete|seis|cinco|cuatro|tres|dos|uno|una|un))?|veintinueve|veintiocho|veintisiete|veintiseis|veinticinco|veinticuatro|veintitres|veintidos|veintiuno|diecinueve|dieciocho|diecisiete|dieciseis|quince|catorce|trece|doce|once|diez|nueve|ocho|siete|seis|cinco|cuatro|tres|dos|uno|una|un';
const String _timePeriodExpression =
    r'am|pm|de la madrugada|por la madrugada|en la madrugada|de la manana|por la manana|en la manana|de la tarde|por la tarde|en la tarde|de la noche|por la noche|en la noche';
const String _spokenTimePrefixExpression =
    r'(?:\b(?:a|para)\s+l(?:a|as)\s+|\bl(?:a|as)\s+|\b)';
const String _requiredSpokenTimePrefixExpression =
    r'\b(?:(?:a|para)\s+)?l(?:a|as)\s+';
const String _voiceEditNumberExpression =
    '$_flexibleNumberExpression|decimo|noveno|octavo|septimo|sexto|quinto|cuarto|tercero|tercer|segundo|primero|primer';

const Map<String, int> _months = <String, int>{
  'enero': 1,
  'febrero': 2,
  'marzo': 3,
  'abril': 4,
  'mayo': 5,
  'junio': 6,
  'julio': 7,
  'agosto': 8,
  'septiembre': 9,
  'setiembre': 9,
  'octubre': 10,
  'noviembre': 11,
  'diciembre': 12,
};

ReminderDraft parseVoiceReminderCommand(
  String transcript, {
  DateTime? now,
  VoiceVocabularyMemory? vocabularyMemory,
}) {
  final referenceNow = now ?? DateTime.now();
  final trimmedTranscript = polishVoiceTranscriptText(
    transcript,
    vocabularyMemory: vocabularyMemory,
  );
  var workingText = _normalizeVoiceText(trimmedTranscript);

  final advanceExtraction = _extractAdvanceMinutes(workingText);
  workingText = advanceExtraction.text;

  final repeatExtraction = _extractRepeatInterval(workingText);
  workingText = repeatExtraction.text;

  final relativeExtraction = _extractRelativeDateTime(
    workingText,
    referenceNow,
  );
  workingText = relativeExtraction.text;

  final dateExtraction = _extractDate(workingText, referenceNow);
  workingText = dateExtraction.text;

  final timeExtraction = _extractTime(workingText);
  workingText = timeExtraction.text;

  final timeOfDayExtraction = _extractTimeOfDay(workingText);
  workingText = timeOfDayExtraction.text;

  final title = _extractTitle(
    workingText,
    trimmedTranscript,
    vocabularyMemory: vocabularyMemory,
  );
  final repeatInterval =
      repeatExtraction.interval ?? ReminderRepeatInterval.none;
  var repeatSettings = repeatExtraction.settings.normalizedForInterval(
    repeatInterval,
  );
  final parsedDate = dateExtraction.value;
  if (repeatInterval == ReminderRepeatInterval.monthly &&
      parsedDate?.monthUsesLastDay == true &&
      !repeatSettings.hasMonthlyPattern) {
    repeatSettings = repeatSettings.copyWith(monthUsesLastDay: true);
  }

  final parsedTime = timeExtraction.value ?? timeOfDayExtraction.value;
  var scheduledAt =
      relativeExtraction.value ??
      _resolveScheduledAt(
        referenceNow,
        date: parsedDate?.date,
        time: parsedTime,
        repeatInterval: repeatInterval,
        repeatSettings: repeatSettings,
      );
  scheduledAt = _ensureFutureScheduledAt(
    scheduledAt,
    referenceNow,
    repeatInterval: repeatInterval,
    repeatSettings: repeatSettings,
  );

  return ReminderDraft(
    title: title,
    scheduledAt: scheduledAt,
    advanceReminderMinutes:
        advanceExtraction.value ?? defaultAdvanceReminderMinutesForKind(),
    repeatInterval: repeatInterval,
    repeatSettings: repeatSettings,
    transcript: trimmedTranscript,
  );
}

String extractVoiceReminderTitle(
  String transcript, {
  DateTime? now,
  VoiceVocabularyMemory? vocabularyMemory,
}) {
  final referenceNow = now ?? DateTime.now();
  var workingText = _normalizeVoiceText(
    polishVoiceTranscriptText(transcript, vocabularyMemory: vocabularyMemory),
  );

  final advanceExtraction = _extractAdvanceMinutes(workingText);
  workingText = advanceExtraction.text;

  final repeatExtraction = _extractRepeatInterval(workingText);
  workingText = repeatExtraction.text;

  final relativeExtraction = _extractRelativeDateTime(
    workingText,
    referenceNow,
  );
  workingText = relativeExtraction.text;

  final dateExtraction = _extractDate(workingText, referenceNow);
  workingText = dateExtraction.text;

  final timeExtraction = _extractTime(workingText);
  workingText = timeExtraction.text;

  final timeOfDayExtraction = _extractTimeOfDay(workingText);
  workingText = timeOfDayExtraction.text;

  final title = _extractTitle(
    workingText,
    '',
    vocabularyMemory: vocabularyMemory,
  );
  if (title == _fallbackVoiceReminderTitle) {
    return '';
  }
  return title;
}

bool isVoiceTaskCommand(String transcript) {
  final text = _normalizeVoiceText(polishVoiceTranscriptText(transcript));
  if (text.isEmpty) {
    return false;
  }

  return RegExp(
        r'^(?:tarea|pendiente|lista|apunta tarea|apuntame tarea|anota tarea|anotame tarea|crea tarea|crear tarea|creame tarea|nueva tarea|modo tarea|modo tareas)\b',
      ).hasMatch(text) ||
      RegExp(
        r'\b(?:sin fecha|sin hora|sin fecha y hora|modo tarea|modo tareas)\b',
      ).hasMatch(text);
}

bool isVoiceShoppingListCommand(String transcript) {
  final text = _normalizeVoiceText(polishVoiceTranscriptText(transcript));
  if (text.isEmpty) {
    return false;
  }

  return RegExp(
    r'^(?:comprar|compra|comprame|comprame|lista de la compra|lista compra)\b',
  ).hasMatch(text);
}

bool isVoiceNoteCommand(String transcript) {
  final text = _normalizeVoiceText(polishVoiceTranscriptText(transcript));
  if (text.isEmpty) {
    return false;
  }

  return RegExp(
    r'^(?:nota|notas|nueva nota|crear nota|crea nota|creame nota|anota nota|anotame nota|apunta nota|apuntame nota|modo nota|guardar nota)\b',
  ).hasMatch(text);
}

String extractVoiceShoppingListTitle(String transcript, {DateTime? now}) {
  final referenceNow = now ?? DateTime.now();
  var workingText = _normalizeVoiceText(polishVoiceTranscriptText(transcript));
  final cleanupPatterns = <RegExp>[
    RegExp(r'^(?:por favor\s+)?(?:comprar|compra|comprame)\s+'),
    RegExp(r'^(?:por favor\s+)?(?:lista\s+de\s+la\s+compra|lista\s+compra)\s+'),
  ];

  for (final pattern in cleanupPatterns) {
    workingText = _cleanText(workingText.replaceFirst(pattern, ' '));
  }

  if (workingText.isEmpty) {
    return '';
  }

  final title = extractVoiceReminderTitle(workingText, now: referenceNow);
  if (title.isEmpty || title == _fallbackVoiceReminderTitle) {
    return _fallbackVoiceReminderTitle;
  }
  return title;
}

ReminderDraft buildVoiceShoppingListDraft(String transcript, {DateTime? now}) {
  final referenceNow = now ?? DateTime.now();
  return ReminderDraft(
    title: extractVoiceShoppingListTitle(transcript, now: referenceNow),
    scheduledAt: referenceNow,
    advanceReminderMinutes: 0,
    repeatInterval: ReminderRepeatInterval.none,
    kind: ReminderKind.shoppingList,
    hasSchedule: false,
    transcript: transcript.trim(),
  );
}

String extractVoiceNoteTitle(String transcript, {DateTime? now}) {
  final referenceNow = now ?? DateTime.now();
  var workingText = _normalizeVoiceText(polishVoiceTranscriptText(transcript));
  final cleanupPatterns = <RegExp>[
    RegExp(r'^(?:por favor\s+)?(?:nota|notas)\s+'),
    RegExp(
      r'^(?:por favor\s+)?(?:apunta|apuntame|anota|anotame|crea|crear|creame|nueva|guardar)\s+(?:una\s+)?nota\s+',
    ),
    RegExp(r'^(?:modo\s+notas?|guardar\s+como\s+nota)\s+'),
  ];

  for (final pattern in cleanupPatterns) {
    workingText = _cleanText(workingText.replaceFirst(pattern, ' '));
  }

  final title = extractVoiceReminderTitle(workingText, now: referenceNow);
  if (title.isEmpty || title == _fallbackVoiceReminderTitle) {
    return _fallbackVoiceReminderTitle;
  }
  return title;
}

ReminderDraft buildVoiceNoteDraft(String transcript, {DateTime? now}) {
  final referenceNow = now ?? DateTime.now();
  return ReminderDraft(
    title: extractVoiceNoteTitle(transcript, now: referenceNow),
    scheduledAt: referenceNow,
    advanceReminderMinutes: 0,
    repeatInterval: ReminderRepeatInterval.none,
    kind: ReminderKind.note,
    hasSchedule: false,
    transcript: transcript.trim(),
  );
}

String extractVoiceTaskTitle(String transcript, {DateTime? now}) {
  final referenceNow = now ?? DateTime.now();
  var workingText = _normalizeVoiceText(polishVoiceTranscriptText(transcript));
  final cleanupPatterns = <RegExp>[
    RegExp(r'^(?:por favor\s+)?(?:tarea|pendiente|lista)\s+'),
    RegExp(
      r'^(?:por favor\s+)?(?:apunta|apuntame|anota|anotame|crea|crear|creame|nueva)\s+(?:una\s+)?(?:tarea|pendiente)\s+',
    ),
    RegExp(r'^(?:modo\s+tareas?|guardar\s+como\s+tarea)\s+'),
    RegExp(r'\b(?:sin fecha y hora|sin fecha|sin hora)\b'),
  ];

  for (final pattern in cleanupPatterns) {
    workingText = _cleanText(workingText.replaceFirst(pattern, ' '));
  }

  final title = extractVoiceReminderTitle(workingText, now: referenceNow);
  if (title.isEmpty || title == _fallbackVoiceReminderTitle) {
    return _fallbackVoiceReminderTitle;
  }
  return title;
}

ReminderDraft buildVoiceTaskDraft(String transcript, {DateTime? now}) {
  final referenceNow = now ?? DateTime.now();
  return ReminderDraft(
    title: extractVoiceTaskTitle(transcript, now: referenceNow),
    scheduledAt: referenceNow,
    advanceReminderMinutes: 0,
    repeatInterval: ReminderRepeatInterval.none,
    kind: ReminderKind.task,
    hasSchedule: false,
    transcript: transcript.trim(),
  );
}

bool hasVoiceReminderCompleteSchedule(String transcript, {DateTime? now}) {
  final referenceNow = now ?? DateTime.now();
  var workingText = _normalizeVoiceText(polishVoiceTranscriptText(transcript));

  final relativeExtraction = _extractRelativeDateTime(
    workingText,
    referenceNow,
  );
  if (relativeExtraction.value != null) {
    return true;
  }
  workingText = relativeExtraction.text;

  final dateExtraction = _extractDate(workingText, referenceNow);
  workingText = dateExtraction.text;

  final timeExtraction = _extractTime(workingText);
  workingText = timeExtraction.text;

  final timeOfDayExtraction = _extractTimeOfDay(workingText);
  final hasExplicitTime =
      timeExtraction.value != null || timeOfDayExtraction.value != null;

  return hasExplicitTime;
}

class _Extraction<T> {
  const _Extraction({required this.text, this.value});

  final String text;
  final T? value;
}

class _RepeatExtraction {
  const _RepeatExtraction({
    required this.text,
    this.interval,
    this.settings = const ReminderRepeatSettings(),
  });

  final String text;
  final ReminderRepeatInterval? interval;
  final ReminderRepeatSettings settings;
}

class _ParsedDate {
  const _ParsedDate({required this.date, this.monthUsesLastDay = false});

  final DateTime date;
  final bool monthUsesLastDay;
}

class _ParsedTime {
  const _ParsedTime({required this.hour, required this.minute});

  final int hour;
  final int minute;
}

class VoiceReminderEditCommand {
  const VoiceReminderEditCommand({
    required this.reminderNumber,
    this.title,
    this.scheduledAt,
    this.advanceReminderMinutes,
    this.repeatInterval,
    this.repeatSettings,
  });

  final int reminderNumber;
  final String? title;
  final DateTime? scheduledAt;
  final int? advanceReminderMinutes;
  final ReminderRepeatInterval? repeatInterval;
  final ReminderRepeatSettings? repeatSettings;

  bool get hasChanges =>
      title != null ||
      scheduledAt != null ||
      advanceReminderMinutes != null ||
      repeatInterval != null;
}

VoiceReminderEditCommand? parseVoiceReminderEditCommand(
  String transcript, {
  DateTime? now,
}) {
  final referenceNow = now ?? DateTime.now();
  final normalizedText = _normalizeVoiceText(
    polishVoiceTranscriptText(transcript),
  );
  if (normalizedText.isEmpty) {
    return null;
  }

  final targetMatch = _findVoiceEditTargetMatch(normalizedText);
  if (targetMatch == null) {
    return null;
  }

  final reminderNumber = _parseVoiceEditNumber(targetMatch.group(1)!);
  if (reminderNumber == null || reminderNumber < 1) {
    return null;
  }

  final editText = _cleanVoiceEditPayload(
    normalizedText.substring(targetMatch.end),
  );
  if (editText.isEmpty) {
    return VoiceReminderEditCommand(reminderNumber: reminderNumber);
  }

  final scheduleIsComplete = hasVoiceReminderCompleteSchedule(
    editText,
    now: referenceNow,
  );
  final draft = parseVoiceReminderCommand(editText, now: referenceNow);
  final title = _extractVoiceEditTitle(editText, now: referenceNow);
  final repeatInterval = _hasVoiceEditRepeatInstruction(editText)
      ? draft.repeatInterval
      : null;

  return VoiceReminderEditCommand(
    reminderNumber: reminderNumber,
    title: title,
    scheduledAt: scheduleIsComplete ? draft.scheduledAt : null,
    advanceReminderMinutes: _hasVoiceEditAdvanceInstruction(editText)
        ? draft.advanceReminderMinutes
        : null,
    repeatInterval: repeatInterval,
    repeatSettings: repeatInterval == null ? null : draft.repeatSettings,
  );
}

Match? _findVoiceEditTargetMatch(String text) {
  final commandMatch = RegExp(
    '\\b(?:editar|edita|cambiar|cambia|modificar|modifica|actualizar|actualiza|corregir|corrige)\\s+(?:el\\s+|la\\s+)?(?:(?:numero|nro|num)\\s+(?:de\\s+)?(?:recordatorio|aviso)\\s+|(?:recordatorio|aviso)\\s+(?:(?:numero|nro|num)\\s+)?|(?:numero|nro|num)\\s+)?($_voiceEditNumberExpression)\\b',
  ).firstMatch(text);
  if (commandMatch != null) {
    return commandMatch;
  }

  final ordinalReminderMatch = RegExp(
    '\\b(?:el\\s+|la\\s+)?($_voiceEditNumberExpression)\\s+(?:recordatorio|aviso)\\b',
  ).firstMatch(text);
  if (ordinalReminderMatch != null) {
    return ordinalReminderMatch;
  }

  final reminderMatch = RegExp(
    '\\b(?:recordatorio|aviso)\\s+(?:(?:numero|nro|num)\\s+)?($_voiceEditNumberExpression)\\b',
  ).firstMatch(text);
  if (reminderMatch != null) {
    return reminderMatch;
  }

  return RegExp(
    '\\b(?:numero|nro|num)\\s+(?:de\\s+)?(?:(?:recordatorio|aviso)\\s+)?($_voiceEditNumberExpression)\\b',
  ).firstMatch(text);
}

int? _parseVoiceEditNumber(String value) {
  final parsedNumber = _parseFlexibleNumber(value);
  if (parsedNumber != null) {
    return parsedNumber;
  }

  return switch (_cleanText(value)) {
    'primer' || 'primero' => 1,
    'segundo' => 2,
    'tercer' || 'tercero' => 3,
    'cuarto' => 4,
    'quinto' => 5,
    'sexto' => 6,
    'septimo' => 7,
    'octavo' => 8,
    'noveno' => 9,
    'decimo' => 10,
    _ => null,
  };
}

String _cleanVoiceEditPayload(String value) {
  var text = _cleanText(value);
  text = text.replaceFirst(
    RegExp(r'^(?:ponlo|ponla|cambialo|cambiala|actualizalo|actualizala)\s+'),
    '',
  );
  text = text.replaceFirst(RegExp(r'^(?:para|por|con)\s+'), '');
  text = text.replaceFirst(RegExp(r'^(?:que\s+sea|dejalo|dejala)\s+'), '');
  return _cleanText(text);
}

String? _extractVoiceEditTitle(String text, {required DateTime now}) {
  var titleText = text;
  for (final pattern in <RegExp>[
    RegExp(r'^(?:titulo|nombre|texto)\s+(?:a\s+|por\s+)?'),
    RegExp(
      r'^(?:cambiar|cambia|editar|edita)\s+(?:el\s+)?titulo\s+(?:a\s+|por\s+)?',
    ),
    RegExp(r'^(?:que\s+diga|llamalo|llamala)\s+'),
  ]) {
    titleText = _cleanText(titleText.replaceFirst(pattern, ' '));
  }

  final title = extractVoiceReminderTitle(titleText, now: now);
  if (title.isEmpty || _isVoiceEditFillerTitle(title)) {
    return null;
  }
  return title;
}

bool _isVoiceEditFillerTitle(String title) {
  return <String>{
    'A',
    'Al',
    'El',
    'La',
    'Las',
    'Los',
    'Para',
    'Por',
    'Con',
    'Que',
    'Sea',
  }.contains(title);
}

bool _hasVoiceEditAdvanceInstruction(String text) {
  return RegExp(r'\b(?:antes|avisa(?:r)?\s+antes)\b').hasMatch(text);
}

bool _hasVoiceEditRepeatInstruction(String text) {
  return RegExp(
    r'\b(?:cada|todos\s+los|todas\s+las|diario|diaria|semanal|mensual|no\s+repetir|sin\s+repeticion)\b',
  ).hasMatch(text);
}

String _normalizeVoiceText(String value) {
  const replacements = <String, String>{
    '\u00e1': 'a',
    '\u00e0': 'a',
    '\u00e4': 'a',
    '\u00e9': 'e',
    '\u00e8': 'e',
    '\u00eb': 'e',
    '\u00ed': 'i',
    '\u00ec': 'i',
    '\u00ef': 'i',
    '\u00f3': 'o',
    '\u00f2': 'o',
    '\u00f6': 'o',
    '\u00fa': 'u',
    '\u00f9': 'u',
    '\u00fc': 'u',
    '\u00f1': 'n',
    '\u00c3\u00a1': 'a',
    '\u00c3\u00a0': 'a',
    '\u00c3\u00a4': 'a',
    '\u00c3\u00a9': 'e',
    '\u00c3\u00a8': 'e',
    '\u00c3\u00ab': 'e',
    '\u00c3\u00ad': 'i',
    '\u00c3\u00ac': 'i',
    '\u00c3\u00af': 'i',
    '\u00c3\u00b3': 'o',
    '\u00c3\u00b2': 'o',
    '\u00c3\u00b6': 'o',
    '\u00c3\u00ba': 'u',
    '\u00c3\u00b9': 'u',
    '\u00c3\u00bc': 'u',
    '\u00c3\u00b1': 'n',
  };

  var normalized = value.toLowerCase();
  replacements.forEach((from, to) {
    normalized = normalized.replaceAll(from, to);
  });
  normalized = normalized.replaceAll(RegExp(r'[.,;:!?]'), ' ');
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  return _normalizeVoiceAliases(normalized);
}

String _normalizeVoiceAliases(String value) {
  const aliases = <String, String>{
    'maniana': 'manana',
    'manyana': 'manana',
    'manhana': 'manana',
    'prosimo': 'proximo',
    'procsimo': 'proximo',
    'prossimo': 'proximo',
    'proxmo': 'proximo',
    'prosima': 'proxima',
    'procsima': 'proxima',
    'prossima': 'proxima',
    'proxma': 'proxima',
    'sinco': 'cinco',
    'sincuenta': 'cincuenta',
    'cinsuenta': 'cincuenta',
    'catorse': 'catorce',
    'katorce': 'catorce',
    'kinse': 'quince',
    'kinze': 'quince',
    'quinze': 'quince',
    'onse': 'once',
    'dose': 'doce',
    'trese': 'trece',
    'diez y seis': 'dieciseis',
    'dies y seis': 'dieciseis',
    'diez y siete': 'diecisiete',
    'dies y siete': 'diecisiete',
    'diez y ocho': 'dieciocho',
    'dies y ocho': 'dieciocho',
    'diez y nueve': 'diecinueve',
    'dies y nueve': 'diecinueve',
    'dieseis': 'dieciseis',
    'diesiseis': 'dieciseis',
    'diesisiete': 'diecisiete',
    'diesiocho': 'dieciocho',
    'diesinueve': 'diecinueve',
    'dies': 'diez',
    'ves': 'vez',
    'veses': 'veces',
  };

  var normalized = ' $value ';
  aliases.forEach((from, to) {
    normalized = normalized.replaceAll(RegExp('\\b$from\\b'), to);
  });
  return _cleanText(normalized);
}

_Extraction<int> _extractAdvanceMinutes(String text) {
  final minuteMatch = RegExp(
    '\\b($_flexibleNumberExpression)\\s+minutos?\\s+antes\\b',
  ).firstMatch(text);
  if (minuteMatch != null) {
    return _Extraction<int>(
      text: _removeMatch(text, minuteMatch),
      value: _parseFlexibleNumber(minuteMatch.group(1)!) ?? 0,
    );
  }

  final hourMatch = RegExp(
    '\\b($_flexibleNumberExpression)\\s+horas?\\s+antes\\b',
  ).firstMatch(text);
  if (hourMatch != null) {
    return _Extraction<int>(
      text: _removeMatch(text, hourMatch),
      value: (_parseFlexibleNumber(hourMatch.group(1)!) ?? 0) * 60,
    );
  }

  if (text.contains('media hora antes')) {
    return _Extraction<int>(
      text: _cleanText(text.replaceFirst('media hora antes', ' ')),
      value: 30,
    );
  }

  if (text.contains('una hora antes')) {
    return _Extraction<int>(
      text: _cleanText(text.replaceFirst('una hora antes', ' ')),
      value: 60,
    );
  }

  return _Extraction<int>(text: text);
}

_Extraction<DateTime> _extractRelativeDateTime(String text, DateTime now) {
  final halfHourMatch = RegExp(
    r'\b(?:dentro de|en)\s+media\s+hora\b',
  ).firstMatch(text);
  if (halfHourMatch != null) {
    return _Extraction<DateTime>(
      text: _removeMatch(text, halfHourMatch),
      value: now.add(const Duration(minutes: 30)),
    );
  }

  final bareHalfHourMatch = RegExp(
    r'(?:^|\s)(?:para\s+)?media\s+hora$',
  ).firstMatch(text);
  if (bareHalfHourMatch != null) {
    return _Extraction<DateTime>(
      text: _removeMatch(text, bareHalfHourMatch),
      value: now.add(const Duration(minutes: 30)),
    );
  }

  final hourAndHalfMatch = RegExp(
    r'\b(?:dentro de|en)\s+(?:(hora)|([a-z0-9]+)\s+horas?)\s+y\s+media\b',
  ).firstMatch(text);
  if (hourAndHalfMatch != null) {
    final rawAmount = hourAndHalfMatch.group(1) != null
        ? 'una'
        : hourAndHalfMatch.group(2);
    final baseHours = rawAmount == null
        ? 1
        : (_parseFlexibleNumber(rawAmount) ?? 1);
    return _Extraction<DateTime>(
      text: _removeMatch(text, hourAndHalfMatch),
      value: now.add(Duration(minutes: (baseHours * 60) + 30)),
    );
  }

  final bareHourAndHalfMatch = RegExp(
    r'(?:^|\s)(?:(hora)|([a-z0-9]+)\s+horas?)\s+y\s+media$',
  ).firstMatch(text);
  if (bareHourAndHalfMatch != null) {
    final rawAmount = bareHourAndHalfMatch.group(1) != null
        ? 'una'
        : bareHourAndHalfMatch.group(2);
    final baseHours = rawAmount == null
        ? 1
        : (_parseFlexibleNumber(rawAmount) ?? 1);
    return _Extraction<DateTime>(
      text: _removeMatch(text, bareHourAndHalfMatch),
      value: now.add(Duration(minutes: (baseHours * 60) + 30)),
    );
  }

  final relativeMatch = RegExp(
    r'\b(?:dentro de|en)\s+([a-z0-9 ]+?)\s+(minutos?|horas?|dias?|semanas?)\b',
  ).firstMatch(text);
  if (relativeMatch != null) {
    return _buildRelativeDateTimeExtraction(
      text,
      relativeMatch,
      now,
      amountGroupIndex: 1,
      unitGroupIndex: 2,
    );
  }

  final bareRelativeMatch = RegExp(
    '(?:^|\\s)(?:para\\s+)?(?:unos?|unas?)?\\s*($_flexibleNumberExpression)\\s+(minutos?|horas?|dias?|semanas?)\$',
  ).firstMatch(text);
  if (bareRelativeMatch == null) {
    return _Extraction<DateTime>(text: text);
  }

  return _buildRelativeDateTimeExtraction(
    text,
    bareRelativeMatch,
    now,
    amountGroupIndex: 1,
    unitGroupIndex: 2,
  );
}

_Extraction<DateTime> _buildRelativeDateTimeExtraction(
  String text,
  Match match,
  DateTime now, {
  required int amountGroupIndex,
  required int unitGroupIndex,
}) {
  final amount = _parseFlexibleNumber(match.group(amountGroupIndex)!);
  if (amount == null) {
    return _Extraction<DateTime>(text: text);
  }

  final unit = match.group(unitGroupIndex)!;
  final scheduledAt = switch (unit) {
    'minuto' || 'minutos' => now.add(Duration(minutes: amount)),
    'hora' || 'horas' => now.add(Duration(hours: amount)),
    'dia' || 'dias' => now.add(Duration(days: amount)),
    'semana' || 'semanas' => now.add(Duration(days: amount * 7)),
    _ => now.add(const Duration(hours: 1)),
  };

  return _Extraction<DateTime>(
    text: _removeMatch(text, match),
    value: scheduledAt,
  );
}

_RepeatExtraction _extractRepeatInterval(String text) {
  final penultimateMonthWeekdayMatch = RegExp(
    r'\b(?:el\s+)?penultimo\s+(lunes|martes|miercoles|jueves|viernes|sabado|domingo)\s+de\s+cada\s+mes\b',
  ).firstMatch(text);
  if (penultimateMonthWeekdayMatch != null) {
    return _RepeatExtraction(
      text: _removeMatch(text, penultimateMonthWeekdayMatch),
      interval: ReminderRepeatInterval.monthly,
      settings: ReminderRepeatSettings(
        monthWeekFromEnd: 2,
        monthWeekday: _weekdays[penultimateMonthWeekdayMatch.group(1)!],
      ),
    );
  }

  final penultimateMonthWeekdayReverseMatch = RegExp(
    r'\bcada\s+mes\s+(?:el\s+)?penultimo\s+(lunes|martes|miercoles|jueves|viernes|sabado|domingo)\b',
  ).firstMatch(text);
  if (penultimateMonthWeekdayReverseMatch != null) {
    return _RepeatExtraction(
      text: _removeMatch(text, penultimateMonthWeekdayReverseMatch),
      interval: ReminderRepeatInterval.monthly,
      settings: ReminderRepeatSettings(
        monthWeekFromEnd: 2,
        monthWeekday: _weekdays[penultimateMonthWeekdayReverseMatch.group(1)!],
      ),
    );
  }

  final lastMonthWeekdayMatch = RegExp(
    r'\b(?:el\s+)?ultimo\s+(lunes|martes|miercoles|jueves|viernes|sabado|domingo)\s+de\s+cada\s+mes\b',
  ).firstMatch(text);
  if (lastMonthWeekdayMatch != null) {
    return _RepeatExtraction(
      text: _removeMatch(text, lastMonthWeekdayMatch),
      interval: ReminderRepeatInterval.monthly,
      settings: ReminderRepeatSettings(
        monthWeekOfMonth: 5,
        monthWeekday: _weekdays[lastMonthWeekdayMatch.group(1)!],
      ),
    );
  }

  final lastMonthWeekdayReverseMatch = RegExp(
    r'\bcada\s+mes\s+(?:el\s+)?ultimo\s+(lunes|martes|miercoles|jueves|viernes|sabado|domingo)\b',
  ).firstMatch(text);
  if (lastMonthWeekdayReverseMatch != null) {
    return _RepeatExtraction(
      text: _removeMatch(text, lastMonthWeekdayReverseMatch),
      interval: ReminderRepeatInterval.monthly,
      settings: ReminderRepeatSettings(
        monthWeekOfMonth: 5,
        monthWeekday: _weekdays[lastMonthWeekdayReverseMatch.group(1)!],
      ),
    );
  }

  final monthWeekdayMatch = RegExp(
    r'\b(?:el\s+)?(primer|segundo|tercer|cuarto|quinto)\s+(lunes|martes|miercoles|jueves|viernes|sabado|domingo)\s+de\s+cada\s+mes\b',
  ).firstMatch(text);
  if (monthWeekdayMatch != null) {
    return _RepeatExtraction(
      text: _removeMatch(text, monthWeekdayMatch),
      interval: ReminderRepeatInterval.monthly,
      settings: ReminderRepeatSettings(
        monthWeekOfMonth: _parseOrdinalWeek(monthWeekdayMatch.group(1)!),
        monthWeekday: _weekdays[monthWeekdayMatch.group(2)!],
      ),
    );
  }

  final monthWeekdayReverseMatch = RegExp(
    r'\bcada\s+mes\s+(?:el\s+)?(primer|segundo|tercer|cuarto|quinto)\s+(lunes|martes|miercoles|jueves|viernes|sabado|domingo)\b',
  ).firstMatch(text);
  if (monthWeekdayReverseMatch != null) {
    return _RepeatExtraction(
      text: _removeMatch(text, monthWeekdayReverseMatch),
      interval: ReminderRepeatInterval.monthly,
      settings: ReminderRepeatSettings(
        monthWeekOfMonth: _parseOrdinalWeek(monthWeekdayReverseMatch.group(1)!),
        monthWeekday: _weekdays[monthWeekdayReverseMatch.group(2)!],
      ),
    );
  }

  final monthlyDayMatch = RegExp(
    r'\b(?:el\s+)?dia\s+(\d{1,2})\s+de\s+cada\s+mes\b',
  ).firstMatch(text);
  if (monthlyDayMatch != null) {
    return _RepeatExtraction(
      text: _removeMatch(text, monthlyDayMatch),
      interval: ReminderRepeatInterval.monthly,
      settings: ReminderRepeatSettings(
        monthDay: int.tryParse(monthlyDayMatch.group(1)!) ?? 1,
      ),
    );
  }

  final monthlyDayReverseMatch = RegExp(
    r'\bcada\s+mes\s+(?:el\s+)?dia\s+(\d{1,2})\b',
  ).firstMatch(text);
  if (monthlyDayReverseMatch != null) {
    return _RepeatExtraction(
      text: _removeMatch(text, monthlyDayReverseMatch),
      interval: ReminderRepeatInterval.monthly,
      settings: ReminderRepeatSettings(
        monthDay: int.tryParse(monthlyDayReverseMatch.group(1)!) ?? 1,
      ),
    );
  }

  final monthEndMatch = RegExp(
    r'\b(?:a\s+)?final(?:es)?\s+de\s+cada\s+mes\b',
  ).firstMatch(text);
  if (monthEndMatch != null) {
    return _RepeatExtraction(
      text: _removeMatch(text, monthEndMatch),
      interval: ReminderRepeatInterval.monthly,
      settings: const ReminderRepeatSettings(monthUsesLastDay: true),
    );
  }

  final monthEndReverseMatch = RegExp(
    r'\bcada\s+mes\s+(?:a\s+)?final(?:es)?\s+de\s+mes\b',
  ).firstMatch(text);
  if (monthEndReverseMatch != null) {
    return _RepeatExtraction(
      text: _removeMatch(text, monthEndReverseMatch),
      interval: ReminderRepeatInterval.monthly,
      settings: const ReminderRepeatSettings(monthUsesLastDay: true),
    );
  }

  final weeklyWeekdayMatch = RegExp(
    r'\b(?:cada|todos los)\s+(lunes|martes|miercoles|jueves|viernes|sabado|domingo)\b',
  ).firstMatch(text);
  if (weeklyWeekdayMatch != null) {
    final weekday = weeklyWeekdayMatch.group(1)!;
    return _RepeatExtraction(
      text: _cleanText(
        text.replaceRange(
          weeklyWeekdayMatch.start,
          weeklyWeekdayMatch.end,
          ' $weekday ',
        ),
      ),
      interval: ReminderRepeatInterval.weekly,
    );
  }

  const patterns = <(String, ReminderRepeatInterval)>[
    ('sin repeticion', ReminderRepeatInterval.none),
    ('no repetir', ReminderRepeatInterval.none),
    ('todos los dias', ReminderRepeatInterval.daily),
    ('cada dia', ReminderRepeatInterval.daily),
    ('diario', ReminderRepeatInterval.daily),
    ('diaria', ReminderRepeatInterval.daily),
    ('cada semana', ReminderRepeatInterval.weekly),
    ('semanal', ReminderRepeatInterval.weekly),
    ('cada mes', ReminderRepeatInterval.monthly),
    ('mensual', ReminderRepeatInterval.monthly),
  ];

  for (final (pattern, interval) in patterns) {
    if (text.contains(pattern)) {
      return _RepeatExtraction(
        text: _cleanText(text.replaceFirst(pattern, ' ')),
        interval: interval,
      );
    }
  }

  return _RepeatExtraction(text: text);
}

_Extraction<_ParsedDate> _extractDate(String text, DateTime now) {
  final penultimateWeekdayOfMonthMatch = RegExp(
    r'\b(?:el\s+)?penultimo\s+(lunes|martes|miercoles|jueves|viernes|sabado|domingo)\s+del\s+mes\b',
  ).firstMatch(text);
  if (penultimateWeekdayOfMonthMatch != null) {
    final weekday = _weekdays[penultimateWeekdayOfMonthMatch.group(1)!]!;
    return _Extraction<_ParsedDate>(
      text: _removeMatch(text, penultimateWeekdayOfMonthMatch),
      value: _ParsedDate(date: _nextWeekdayFromEndOfMonth(now, weekday, 2)),
    );
  }

  final lastWeekdayOfMonthMatch = RegExp(
    r'\b(?:el\s+)?ultimo\s+(lunes|martes|miercoles|jueves|viernes|sabado|domingo)\s+del\s+mes\b',
  ).firstMatch(text);
  if (lastWeekdayOfMonthMatch != null) {
    final weekday = _weekdays[lastWeekdayOfMonthMatch.group(1)!]!;
    return _Extraction<_ParsedDate>(
      text: _removeMatch(text, lastWeekdayOfMonthMatch),
      value: _ParsedDate(date: _nextLastWeekdayOfMonth(now, weekday)),
    );
  }

  final endOfMonthMatch = RegExp(
    r'\b(?:a\s+)?final(?:es)?\s+de\s+mes\b',
  ).firstMatch(text);
  if (endOfMonthMatch != null) {
    return _Extraction<_ParsedDate>(
      text: _removeMatch(text, endOfMonthMatch),
      value: _ParsedDate(date: _endOfMonthDate(now), monthUsesLastDay: true),
    );
  }

  final dayOfMonthMatch = RegExp(
    r'\b(?:el\s+)?dia\s+(\d{1,2})\b',
  ).firstMatch(text);
  if (dayOfMonthMatch != null) {
    final day = int.tryParse(dayOfMonthMatch.group(1)!) ?? now.day;
    return _Extraction<_ParsedDate>(
      text: _removeMatch(text, dayOfMonthMatch),
      value: _ParsedDate(date: _nextDayOfMonth(now, day)),
    );
  }

  if (text.contains('pasado manana')) {
    return _Extraction<_ParsedDate>(
      text: _cleanText(text.replaceFirst('pasado manana', ' ')),
      value: _ParsedDate(date: DateTime(now.year, now.month, now.day + 2)),
    );
  }

  final tomorrowMatch = _firstStandaloneTomorrowMatch(text);
  if (tomorrowMatch != null) {
    return _Extraction<_ParsedDate>(
      text: _removeMatch(text, tomorrowMatch),
      value: _ParsedDate(date: DateTime(now.year, now.month, now.day + 1)),
    );
  }

  if (text.contains('hoy')) {
    return _Extraction<_ParsedDate>(
      text: _cleanText(text.replaceFirst('hoy', ' ')),
      value: _ParsedDate(date: DateTime(now.year, now.month, now.day)),
    );
  }

  final explicitDateMatch = RegExp(
    r'\b(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?\b',
  ).firstMatch(text);
  if (explicitDateMatch != null) {
    final day = int.tryParse(explicitDateMatch.group(1)!) ?? now.day;
    final month = int.tryParse(explicitDateMatch.group(2)!) ?? now.month;
    final rawYear = explicitDateMatch.group(3);
    final year = rawYear == null
        ? now.year
        : rawYear.length == 2
        ? 2000 + (int.tryParse(rawYear) ?? 0)
        : int.tryParse(rawYear) ?? now.year;

    return _Extraction<_ParsedDate>(
      text: _removeMatch(text, explicitDateMatch),
      value: _ParsedDate(date: DateTime(year, month, day)),
    );
  }

  final monthDateMatch = RegExp(
    '\\b(?:el\\s+)?($_flexibleNumberExpression)\\s+(?:de\\s+)?(${_months.keys.join('|')})(?:\\s+(?:de\\s+)?(\\d{2,4}))?\\b',
  ).firstMatch(text);
  if (monthDateMatch != null) {
    final day = _parseFlexibleNumber(monthDateMatch.group(1)!) ?? now.day;
    final month = _months[monthDateMatch.group(2)!] ?? now.month;
    final rawYear = monthDateMatch.group(3);
    final parsedYear = rawYear == null
        ? null
        : rawYear.length == 2
        ? 2000 + (int.tryParse(rawYear) ?? 0)
        : int.tryParse(rawYear);
    return _Extraction<_ParsedDate>(
      text: _removeMatch(text, monthDateMatch),
      value: _ParsedDate(
        date: _resolveMonthDate(now, day: day, month: month, year: parsedYear),
      ),
    );
  }

  for (final entry in _weekdays.entries) {
    final explicitWeekdayMatch = RegExp(
      '\\b(?:el\\s+)?(?:(?:este|esta|proximo|proxima|siguiente)\\s+${entry.key}|${entry.key}\\s+que\\s+viene)\\b',
    ).firstMatch(text);
    if (explicitWeekdayMatch != null) {
      var difference = (entry.value - now.weekday) % 7;
      final matchText = text.substring(
        explicitWeekdayMatch.start,
        explicitWeekdayMatch.end,
      );
      if ((matchText.contains('proximo') ||
              matchText.contains('proxima') ||
              matchText.contains('siguiente') ||
              matchText.contains('que viene')) &&
          difference == 0) {
        difference = 7;
      }
      return _Extraction<_ParsedDate>(
        text: _removeMatch(text, explicitWeekdayMatch),
        value: _ParsedDate(
          date: DateTime(now.year, now.month, now.day + difference),
        ),
      );
    }

    final weekdayMatch = RegExp(
      '\\b(?:el\\s+)?${entry.key}\\b',
    ).firstMatch(text);
    if (weekdayMatch != null) {
      final difference = (entry.value - now.weekday) % 7;
      return _Extraction<_ParsedDate>(
        text: _removeMatch(text, weekdayMatch),
        value: _ParsedDate(
          date: DateTime(now.year, now.month, now.day + difference),
        ),
      );
    }
  }

  return _Extraction<_ParsedDate>(text: text);
}

Match? _firstStandaloneTomorrowMatch(String text) {
  final matches = RegExp(r'\bmanana\b').allMatches(text);
  for (final match in matches) {
    final prefix = text.substring(0, match.start).trimRight();
    if (prefix.endsWith('de la') ||
        prefix.endsWith('por la') ||
        prefix.endsWith('en la')) {
      continue;
    }
    return match;
  }
  return null;
}

_Extraction<_ParsedTime> _extractTime(String text) {
  final halfHourMatch = RegExp(
    '$_spokenTimePrefixExpression($_flexibleNumberExpression)\\s+y\\s+media(?:\\s+($_timePeriodExpression))?\\b',
  ).firstMatch(text);
  if (halfHourMatch != null) {
    return _Extraction<_ParsedTime>(
      text: _removeMatch(text, halfHourMatch),
      value: _ParsedTime(
        hour: _resolveHour(
          _parseFlexibleNumber(halfHourMatch.group(1)!) ?? 9,
          halfHourMatch.group(2),
        ),
        minute: 30,
      ),
    );
  }

  final spokenMinuteMatch = RegExp(
    '$_spokenTimePrefixExpression($_flexibleNumberExpression)\\s+(?:y|con)\\s+($_flexibleNumberExpression)(?:\\s+($_timePeriodExpression))?\\b',
  ).firstMatch(text);
  if (spokenMinuteMatch != null) {
    return _Extraction<_ParsedTime>(
      text: _removeMatch(text, spokenMinuteMatch),
      value: _ParsedTime(
        hour: _resolveHour(
          _parseFlexibleNumber(spokenMinuteMatch.group(1)!) ?? 9,
          spokenMinuteMatch.group(3),
        ),
        minute: _parseFlexibleNumber(spokenMinuteMatch.group(2)!) ?? 0,
      ),
    );
  }

  final spaceSeparatedTimeWithPeriodMatch = RegExp(
    '$_spokenTimePrefixExpression(\\d{1,2})\\s+(\\d{2})(?:\\s+($_timePeriodExpression))?\\b',
  ).firstMatch(text);
  if (spaceSeparatedTimeWithPeriodMatch != null) {
    return _Extraction<_ParsedTime>(
      text: _removeMatch(text, spaceSeparatedTimeWithPeriodMatch),
      value: _ParsedTime(
        hour: _resolveHour(
          int.tryParse(spaceSeparatedTimeWithPeriodMatch.group(1)!) ?? 9,
          spaceSeparatedTimeWithPeriodMatch.group(3),
        ),
        minute: int.tryParse(spaceSeparatedTimeWithPeriodMatch.group(2)!) ?? 0,
      ),
    );
  }

  final prefixedTimeMatch = RegExp(
    '$_requiredSpokenTimePrefixExpression($_flexibleNumberExpression)(?::(\\d{2}))?\\s*($_timePeriodExpression)?\\b',
  ).firstMatch(text);
  if (prefixedTimeMatch != null) {
    return _Extraction<_ParsedTime>(
      text: _removeMatch(text, prefixedTimeMatch),
      value: _ParsedTime(
        hour: _resolveHour(
          _parseFlexibleNumber(prefixedTimeMatch.group(1)!) ?? 9,
          prefixedTimeMatch.group(3),
        ),
        minute: int.tryParse(prefixedTimeMatch.group(2) ?? '0') ?? 0,
      ),
    );
  }

  final simpleTimeWithPeriodMatch = RegExp(
    '\\b(\\d{1,2}):(\\d{2})\\s*($_timePeriodExpression)\\b',
  ).firstMatch(text);
  if (simpleTimeWithPeriodMatch != null) {
    return _Extraction<_ParsedTime>(
      text: _removeMatch(text, simpleTimeWithPeriodMatch),
      value: _ParsedTime(
        hour: _resolveHour(
          int.tryParse(simpleTimeWithPeriodMatch.group(1)!) ?? 9,
          simpleTimeWithPeriodMatch.group(3),
        ),
        minute: int.tryParse(simpleTimeWithPeriodMatch.group(2)!) ?? 0,
      ),
    );
  }

  final simpleTimeMatch = RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(text);
  if (simpleTimeMatch != null) {
    return _Extraction<_ParsedTime>(
      text: _removeMatch(text, simpleTimeMatch),
      value: _ParsedTime(
        hour: int.tryParse(simpleTimeMatch.group(1)!) ?? 9,
        minute: int.tryParse(simpleTimeMatch.group(2)!) ?? 0,
      ),
    );
  }

  return _Extraction<_ParsedTime>(text: text);
}

_Extraction<_ParsedTime> _extractTimeOfDay(String text) {
  const patterns = <(String, _ParsedTime)>[
    ('a primera hora', _ParsedTime(hour: 8, minute: 0)),
    ('primera hora', _ParsedTime(hour: 8, minute: 0)),
    ('de la manana', _ParsedTime(hour: 9, minute: 0)),
    ('por la manana', _ParsedTime(hour: 9, minute: 0)),
    ('en la manana', _ParsedTime(hour: 9, minute: 0)),
    ('de la tarde', _ParsedTime(hour: 18, minute: 0)),
    ('por la tarde', _ParsedTime(hour: 18, minute: 0)),
    ('en la tarde', _ParsedTime(hour: 18, minute: 0)),
    ('de la noche', _ParsedTime(hour: 21, minute: 0)),
    ('por la noche', _ParsedTime(hour: 21, minute: 0)),
    ('en la noche', _ParsedTime(hour: 21, minute: 0)),
    ('de la madrugada', _ParsedTime(hour: 7, minute: 0)),
    ('por la madrugada', _ParsedTime(hour: 7, minute: 0)),
    ('en la madrugada', _ParsedTime(hour: 7, minute: 0)),
    ('al mediodia', _ParsedTime(hour: 14, minute: 0)),
    ('al medio dia', _ParsedTime(hour: 14, minute: 0)),
    ('mediodia', _ParsedTime(hour: 14, minute: 0)),
    ('medio dia', _ParsedTime(hour: 14, minute: 0)),
  ];

  for (final (pattern, parsedTime) in patterns) {
    if (text.contains(pattern)) {
      return _Extraction<_ParsedTime>(
        text: _cleanText(text.replaceFirst(pattern, ' ')),
        value: parsedTime,
      );
    }
  }

  return _Extraction<_ParsedTime>(text: text);
}

DateTime _resolveScheduledAt(
  DateTime now, {
  DateTime? date,
  _ParsedTime? time,
  required ReminderRepeatInterval repeatInterval,
  required ReminderRepeatSettings repeatSettings,
}) {
  final resolvedTime = time ?? const _ParsedTime(hour: 9, minute: 0);

  if (date != null) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      resolvedTime.hour,
      resolvedTime.minute,
    );
  }

  if (repeatInterval == ReminderRepeatInterval.monthly &&
      repeatSettings.hasMonthlyPattern) {
    return _resolveFirstMonthlyOccurrence(now, repeatSettings, resolvedTime);
  }

  if (time != null) {
    final sameDay = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (sameDay.isAfter(now)) {
      return sameDay;
    }
    return sameDay.add(const Duration(days: 1));
  }

  final nextHour = now.add(const Duration(hours: 1));
  return DateTime(nextHour.year, nextHour.month, nextHour.day, nextHour.hour);
}

DateTime _ensureFutureScheduledAt(
  DateTime scheduledAt,
  DateTime now, {
  required ReminderRepeatInterval repeatInterval,
  required ReminderRepeatSettings repeatSettings,
}) {
  if (scheduledAt.isAfter(now)) {
    return scheduledAt;
  }

  if (repeatInterval.isRepeating) {
    var nextScheduledAt = scheduledAt;
    while (!nextScheduledAt.isAfter(now)) {
      nextScheduledAt = nextReminderOccurrence(
        nextScheduledAt,
        repeatInterval,
        repeatSettings: repeatSettings,
      );
    }
    return nextScheduledAt;
  }

  final nextHour = now.add(const Duration(hours: 1));
  return DateTime(nextHour.year, nextHour.month, nextHour.day, nextHour.hour);
}

DateTime _resolveFirstMonthlyOccurrence(
  DateTime now,
  ReminderRepeatSettings repeatSettings,
  _ParsedTime time,
) {
  var candidate = _buildMonthlyCandidate(
    year: now.year,
    month: now.month,
    repeatSettings: repeatSettings,
    fallbackDay: now.day,
    time: time,
  );

  if (!candidate.isAfter(now)) {
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    candidate = _buildMonthlyCandidate(
      year: nextMonth.year,
      month: nextMonth.month,
      repeatSettings: repeatSettings,
      fallbackDay: now.day,
      time: time,
    );
  }

  return candidate;
}

DateTime _buildMonthlyCandidate({
  required int year,
  required int month,
  required ReminderRepeatSettings repeatSettings,
  required int fallbackDay,
  required _ParsedTime time,
}) {
  final day = switch (repeatSettings.monthUsesLastDay) {
    true => DateTime(year, month + 1, 0).day,
    false when repeatSettings.monthWeekFromEnd != null =>
      _weekdayFromEndOfMonth(
        year,
        month,
        repeatSettings.monthWeekday!,
        repeatSettings.monthWeekFromEnd!,
      ).day,
    false when repeatSettings.hasMonthWeekdayPattern => _dayForWeekdayOfMonth(
      year,
      month,
      repeatSettings.monthWeekday!,
      repeatSettings.monthWeekOfMonth!,
    ),
    _ => _safeMonthDay(year, month, repeatSettings.monthDay ?? fallbackDay),
  };

  return DateTime(year, month, day, time.hour, time.minute);
}

String _extractTitle(
  String normalizedText,
  String fallbackTranscript, {
  VoiceVocabularyMemory? vocabularyMemory,
}) {
  var title = normalizedText;
  const leadingPatterns = <String>[
    r'^por favor\b',
    r'^recordarme\b',
    r'^recordame\b',
    r'^recuerdame\b',
    r'^acuerdame\b',
    r'^avisame\b',
    r'^avisa\b',
    r'^agendame\b',
    r'^agenda\b',
    r'^programame\b',
    r'^programa\b',
    r'^ponme\b',
    r'^pon\b',
    r'^anotame\b',
    r'^apuntame\b',
    r'^crear recordatorio\b',
    r'^creame recordatorio\b',
    r'^creame un recordatorio\b',
    r'^crea recordatorio\b',
    r'^crea un recordatorio\b',
    r'^nuevo recordatorio\b',
    r'^recordatorio\b',
    r'^recordar\b',
    r'^anota\b',
    r'^apunta\b',
    r'^necesito\b',
    r'^quiero\b',
    r'^que\b',
  ];

  for (final pattern in leadingPatterns) {
    title = _cleanText(title.replaceFirst(RegExp(pattern), ' '));
  }

  title = _cleanText(title);
  if (title.isNotEmpty) {
    return polishVoiceTitleText(title, vocabularyMemory: vocabularyMemory);
  }

  var originalFallback = fallbackTranscript.trim();
  for (final pattern in <RegExp>[
    RegExp(
      r'^(recordarme|recordame|recuerdame|acuerdame|avisame|agendame|programame|anotame|apuntame)\s+',
      caseSensitive: false,
    ),
    RegExp(
      r'^(crear|crea|creame)\s+(un\s+)?recordatorio\s+',
      caseSensitive: false,
    ),
    RegExp(r'^nuevo\s+recordatorio\s+', caseSensitive: false),
    RegExp(r'^recordatorio\s+', caseSensitive: false),
  ]) {
    originalFallback = originalFallback.replaceFirst(pattern, '');
  }

  originalFallback = originalFallback.trim();
  if (originalFallback.isNotEmpty) {
    return polishVoiceTitleText(
      originalFallback,
      vocabularyMemory: vocabularyMemory,
    );
  }

  return _fallbackVoiceReminderTitle;
}

int _resolveHour(int hour, String? period) {
  if (period == null) {
    return hour;
  }

  if ((period == 'pm' ||
          period == 'de la tarde' ||
          period == 'de la noche' ||
          period == 'por la tarde' ||
          period == 'por la noche' ||
          period == 'en la tarde' ||
          period == 'en la noche') &&
      hour < 12) {
    return hour + 12;
  }

  if ((period == 'am' ||
          period == 'de la manana' ||
          period == 'por la manana' ||
          period == 'en la manana') &&
      hour == 12) {
    return 0;
  }

  if ((period == 'de la madrugada' ||
          period == 'por la madrugada' ||
          period == 'en la madrugada') &&
      hour == 12) {
    return 0;
  }

  return hour;
}

int? _parseFlexibleNumber(String value) {
  final normalizedValue = _cleanText(value);
  final parsedInt = int.tryParse(normalizedValue);
  if (parsedInt != null) {
    return parsedInt;
  }

  const values = <String, int>{
    'cero': 0,
    'un': 1,
    'una': 1,
    'uno': 1,
    'primer': 1,
    'primero': 1,
    'dos': 2,
    'tres': 3,
    'cuatro': 4,
    'cinco': 5,
    'seis': 6,
    'siete': 7,
    'ocho': 8,
    'nueve': 9,
    'diez': 10,
    'once': 11,
    'doce': 12,
    'trece': 13,
    'catorce': 14,
    'quince': 15,
    'dieciseis': 16,
    'diecisiete': 17,
    'dieciocho': 18,
    'diecinueve': 19,
    'veinte': 20,
    'veintiuno': 21,
    'veintidos': 22,
    'veintitres': 23,
    'veinticuatro': 24,
    'veinticinco': 25,
    'veintiseis': 26,
    'veintisiete': 27,
    'veintiocho': 28,
    'veintinueve': 29,
    'treinta': 30,
    'treinta y uno': 31,
    'cuarenta': 40,
    'cincuenta': 50,
  };

  final directValue = values[normalizedValue];
  if (directValue != null) {
    return directValue;
  }

  final compoundMatch = RegExp(
    r'^(veinte|treinta|cuarenta|cincuenta) y (un|una|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve)$',
  ).firstMatch(normalizedValue);
  if (compoundMatch == null) {
    return null;
  }

  final tens = values[compoundMatch.group(1)!];
  final units = values[compoundMatch.group(2)!];
  if (tens == null || units == null) {
    return null;
  }
  return tens + units;
}

int? _parseOrdinalWeek(String value) {
  return switch (value) {
    'primer' || 'primero' => 1,
    'segundo' => 2,
    'tercer' || 'tercero' => 3,
    'cuarto' => 4,
    'quinto' => 5,
    _ => null,
  };
}

DateTime _nextDayOfMonth(DateTime now, int day) {
  final currentMonthLastDay = DateTime(now.year, now.month + 1, 0).day;
  final safeCurrentDay = day <= currentMonthLastDay ? day : currentMonthLastDay;
  final today = DateTime(now.year, now.month, now.day);
  var candidate = DateTime(now.year, now.month, safeCurrentDay);

  if (candidate.isBefore(today)) {
    final nextMonthLastDay = DateTime(now.year, now.month + 2, 0).day;
    final safeNextDay = day <= nextMonthLastDay ? day : nextMonthLastDay;
    candidate = DateTime(now.year, now.month + 1, safeNextDay);
  }

  return candidate;
}

DateTime _resolveMonthDate(
  DateTime now, {
  required int day,
  required int month,
  int? year,
}) {
  final targetYear = year ?? now.year;
  final safeDay = _safeMonthDay(targetYear, month, day);
  var candidate = DateTime(targetYear, month, safeDay);
  final today = DateTime(now.year, now.month, now.day);
  if (year == null && candidate.isBefore(today)) {
    final nextYear = targetYear + 1;
    candidate = DateTime(nextYear, month, _safeMonthDay(nextYear, month, day));
  }
  return candidate;
}

DateTime _endOfMonthDate(DateTime now) {
  final candidate = DateTime(now.year, now.month + 1, 0);
  final today = DateTime(now.year, now.month, now.day);
  if (!candidate.isBefore(today)) {
    return candidate;
  }
  return DateTime(now.year, now.month + 2, 0);
}

DateTime _nextLastWeekdayOfMonth(DateTime now, int weekday) {
  var candidate = _weekdayFromEndOfMonth(now.year, now.month, weekday, 1);
  final today = DateTime(now.year, now.month, now.day);
  if (!candidate.isBefore(today)) {
    return candidate;
  }

  final nextMonth = DateTime(now.year, now.month + 1, 1);
  return _weekdayFromEndOfMonth(nextMonth.year, nextMonth.month, weekday, 1);
}

DateTime _nextWeekdayFromEndOfMonth(
  DateTime now,
  int weekday,
  int weekFromEnd,
) {
  var candidate = _weekdayFromEndOfMonth(
    now.year,
    now.month,
    weekday,
    weekFromEnd,
  );
  final today = DateTime(now.year, now.month, now.day);
  if (!candidate.isBefore(today)) {
    return candidate;
  }

  final nextMonth = DateTime(now.year, now.month + 1, 1);
  return _weekdayFromEndOfMonth(
    nextMonth.year,
    nextMonth.month,
    weekday,
    weekFromEnd,
  );
}

DateTime _weekdayFromEndOfMonth(
  int year,
  int month,
  int weekday,
  int weekFromEnd,
) {
  final lastDay = DateTime(year, month + 1, 0);
  final difference = (lastDay.weekday - weekday + 7) % 7;
  return DateTime(
    year,
    month,
    lastDay.day - difference - ((weekFromEnd - 1) * 7),
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

String _removeMatch(String text, Match match) {
  return _cleanText(text.replaceRange(match.start, match.end, ' '));
}

String _cleanText(String text) {
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

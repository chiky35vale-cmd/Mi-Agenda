import 'package:intl/intl.dart';

import '../models/reminder.dart';
import 'voice_text_polisher.dart';

final DateFormat _fullDateTimeFormatter = DateFormat(
  "EEE d MMM 'a las' HH:mm",
  'es_ES',
);
final DateFormat _dateFormatter = DateFormat("EEEE d 'de' MMMM", 'es_ES');
final DateFormat _timeFormatter = DateFormat('HH:mm', 'es_ES');

String formatReminderDateTime(DateTime dateTime) {
  return _capitalize(_fullDateTimeFormatter.format(dateTime));
}

String formatReminderDate(DateTime dateTime) {
  return _capitalize(_dateFormatter.format(dateTime));
}

String formatReminderTime(DateTime dateTime) {
  return _timeFormatter.format(dateTime);
}

String describeReminderAlert(Reminder reminder) {
  if (reminder.isShoppingListItem) {
    return 'Producto de la lista de la compra';
  }
  if (reminder.isNote) {
    return 'Nota guardada sin alarma';
  }
  if (!reminder.hasSchedule || reminder.isTask) {
    return 'Tarea sin fecha: visible en tu lista diaria';
  }
  if (reminder.isSnoozed) {
    return 'Pospuesto hasta ${formatReminderDateTime(reminder.notificationAt)}';
  }
  if (!reminder.hasAdvanceReminder) {
    return 'Aviso a la hora exacta';
  }
  return 'Aviso ${formatAdvanceReminderLabel(reminder.advanceReminderMinutes)}';
}

String describeReminderRepeat(Reminder reminder) {
  if (reminder.isShoppingListItem) {
    return 'Lista de la Compra';
  }
  if (reminder.isNote) {
    return 'Nota sin fecha';
  }
  if (!reminder.hasSchedule || reminder.isTask) {
    return 'Sin fecha ni hora';
  }
  return describeRepeatReminder(
    reminder.repeatInterval,
    repeatSettings: reminder.repeatSettings,
  );
}

String describeReminderStatus(Reminder reminder) {
  if (reminder.isCompleted) {
    return 'Completado';
  }
  if (reminder.isShoppingListItem) {
    return 'Pendiente de comprar';
  }
  if (reminder.isNote) {
    return 'Nota guardada';
  }
  if (!reminder.hasSchedule || reminder.isTask) {
    return 'Tarea pendiente';
  }
  if (reminder.isSnoozed) {
    return 'Aviso pospuesto';
  }
  if (reminder.isOverdue) {
    return 'Pendiente fuera de hora';
  }
  if (reminder.hasAdvanceReminder) {
    return 'Aviso activo ${formatAdvanceReminderLabel(reminder.advanceReminderMinutes)}';
  }
  return 'Aviso activo';
}

String describeReminderListLabel(Reminder reminder) {
  if (reminder.isCompleted) {
    if (reminder.isShoppingListItem) {
      return 'Compra Completada';
    }
    if (reminder.isNote) {
      return 'Nota Archivada';
    }
    if (reminder.isTask) {
      return 'Tarea Completada';
    }
    if (reminder.hasSchedule) {
      return formatReminderDateTime(reminder.scheduledAt);
    }
    return 'Completado';
  }
  if (reminder.isShoppingListItem) {
    return 'Compra Pendiente';
  }
  if (reminder.isNote) {
    return 'Nota';
  }
  if (!reminder.hasSchedule || reminder.isTask) {
    return 'Tarea Pendiente';
  }
  return formatReminderDateTime(reminder.scheduledAt);
}

List<String> describeReminderListDetails(Reminder reminder) {
  if (reminder.isShoppingListItem ||
      reminder.isNote ||
      reminder.isTask ||
      !reminder.hasSchedule) {
    return const <String>[];
  }

  final details = <String>[];

  if (!reminder.isCompleted) {
    if (reminder.isSnoozed) {
      details.add(
        'Pospuesto hasta ${formatReminderDateTime(reminder.notificationAt)}',
      );
    } else if (reminder.hasAdvanceReminder) {
      details.add(
        'Aviso ${formatAdvanceReminderLabel(reminder.advanceReminderMinutes)}',
      );
    }

    if (reminder.isRepeating) {
      details.add(
        describeRepeatReminder(
          reminder.repeatInterval,
          repeatSettings: reminder.repeatSettings,
        ),
      );
    }
  }

  return details;
}

String describeReadableReminderParagraph(Reminder reminder) {
  final title = formatReadableReminderTitle(reminder.title);
  if (reminder.isShoppingListItem) {
    return 'Compra pendiente: $title';
  }
  if (reminder.isNote) {
    return 'Nota: $title';
  }
  if (!reminder.hasSchedule || reminder.isTask) {
    return 'Tarea pendiente: $title';
  }

  final day = describeFriendlyDay(reminder.scheduledAt);
  final time = formatReminderTime(reminder.scheduledAt);
  final alert = reminder.hasAdvanceReminder
      ? 'Te avisare ${formatAdvanceReminderLabel(reminder.advanceReminderMinutes)}.'
      : 'Te avisare a la hora exacta.';
  final repeat = reminder.isRepeating
      ? ' Repeticion: ${describeReminderRepeat(reminder).toLowerCase()}.'
      : '';

  return 'Recordatorio: $title Programado para $day a las $time. $alert$repeat';
}

String describeSummaryMessage(Reminder? nextReminder, int pendingCount) {
  if (pendingCount == 0) {
    return 'No tienes avisos pendientes. Todo esta al dia.';
  }
  if (nextReminder == null) {
    return 'Tienes $pendingCount tareas o recordatorios pendientes sin un aviso futuro.';
  }
  return 'Proximo aviso: ${describeFriendlyDay(nextReminder.notificationAt)} a las ${formatReminderTime(nextReminder.notificationAt)}.';
}

String describeFriendlyDay(DateTime dateTime) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
  final difference = target.difference(today).inDays;

  if (difference == 0) {
    return 'hoy';
  }
  if (difference == 1) {
    return 'manana';
  }
  return formatReminderDate(dateTime);
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

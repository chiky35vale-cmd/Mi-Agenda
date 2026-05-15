import 'dart:math' as math;

import 'package:intl/intl.dart';

class MonthWeekSection {
  const MonthWeekSection({
    required this.weekNumber,
    required this.startDate,
    required this.endDate,
    required this.availableDates,
  });

  final int weekNumber;
  final DateTime startDate;
  final DateTime endDate;
  final List<DateTime> availableDates;
}

List<MonthWeekSection> buildAvailableMonthWeekSections(DateTime referenceDate) {
  final today = DateTime(
    referenceDate.year,
    referenceDate.month,
    referenceDate.day,
  );
  final lastDayOfMonth = DateTime(today.year, today.month + 1, 0).day;
  final sections = <MonthWeekSection>[];

  for (var startDay = 1; startDay <= lastDayOfMonth; startDay += 7) {
    final endDay = math.min(startDay + 6, lastDayOfMonth);
    final availableStartDay = math.max(startDay, today.day);
    if (availableStartDay > endDay) {
      continue;
    }

    final weekNumber = ((startDay - 1) ~/ 7) + 1;
    final availableDates = List<DateTime>.generate(
      endDay - availableStartDay + 1,
      (index) => DateTime(today.year, today.month, availableStartDay + index),
    );

    sections.add(
      MonthWeekSection(
        weekNumber: weekNumber,
        startDate: DateTime(today.year, today.month, startDay),
        endDate: DateTime(today.year, today.month, endDay),
        availableDates: availableDates,
      ),
    );
  }

  return sections;
}

String formatMonthWeekSectionLabel(MonthWeekSection section) {
  final monthName = DateFormat('MMMM', 'es_ES').format(section.startDate);
  if (section.startDate.day == section.endDate.day) {
    return 'Semana ${section.weekNumber} - ${section.startDate.day} $monthName';
  }

  return 'Semana ${section.weekNumber} - ${section.startDate.day}-${section.endDate.day} $monthName';
}

DateTime startOfNextMonth(DateTime referenceDate) {
  return DateTime(referenceDate.year, referenceDate.month + 1, 1);
}

List<List<DateTime?>> buildCompactMonthCalendarRows({
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final normalizedFirst = DateTime(
    firstDate.year,
    firstDate.month,
    firstDate.day,
  );
  final normalizedLast = DateTime(lastDate.year, lastDate.month, lastDate.day);
  final rows = <List<DateTime?>>[];
  var rowStart = normalizedFirst.subtract(
    Duration(days: normalizedFirst.weekday - DateTime.monday),
  );

  while (!rowStart.isAfter(normalizedLast)) {
    rows.add(
      List<DateTime?>.generate(7, (index) {
        final day = rowStart.add(Duration(days: index));
        if (day.isBefore(normalizedFirst) || day.isAfter(normalizedLast)) {
          return null;
        }
        return day;
      }),
    );
    rowStart = rowStart.add(const Duration(days: 7));
  }

  return rows;
}

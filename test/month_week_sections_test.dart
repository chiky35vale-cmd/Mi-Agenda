import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_agenda/src/utils/month_week_sections.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES');
  });

  group('buildAvailableMonthWeekSections', () {
    test('agrupa el mes en bloques semanales y recorta los dias pasados', () {
      final sections = buildAvailableMonthWeekSections(DateTime(2026, 4, 3));

      expect(sections, hasLength(5));
      expect(sections.first.weekNumber, 1);
      expect(sections.first.startDate, DateTime(2026, 4, 1));
      expect(sections.first.endDate, DateTime(2026, 4, 7));
      expect(sections.first.availableDates.first, DateTime(2026, 4, 3));
      expect(sections.first.availableDates.last, DateTime(2026, 4, 7));
      expect(sections.last.weekNumber, 5);
      expect(sections.last.endDate, DateTime(2026, 4, 30));
    });

    test('omite las semanas ya pasadas y deja el resto del mes disponible', () {
      final sections = buildAvailableMonthWeekSections(DateTime(2026, 4, 15));

      expect(sections, hasLength(3));
      expect(sections.first.weekNumber, 3);
      expect(sections.first.startDate, DateTime(2026, 4, 15));
      expect(sections.first.endDate, DateTime(2026, 4, 21));
      expect(sections.last.weekNumber, 5);
      expect(sections.last.availableDates, <DateTime>[
        DateTime(2026, 4, 29),
        DateTime(2026, 4, 30),
      ]);
    });
  });

  test('formatMonthWeekSectionLabel muestra semana y rango del mes', () {
    final label = formatMonthWeekSectionLabel(
      MonthWeekSection(
        weekNumber: 4,
        startDate: DateTime(2026, 4, 22),
        endDate: DateTime(2026, 4, 28),
        availableDates: <DateTime>[DateTime(2026, 4, 22)],
      ),
    );

    expect(label, 'Semana 4 - 22-28 abril');
  });

  test(
    'buildCompactMonthCalendarRows alinea el resto del mes en formato calendario',
    () {
      final firstDate = DateTime(2026, 4, 8);
      final lastDate = DateTime(2026, 4, 30);

      final rows = buildCompactMonthCalendarRows(
        firstDate: firstDate,
        lastDate: lastDate,
      );

      expect(rows, hasLength(4));
      for (var index = 0; index < firstDate.weekday - 1; index += 1) {
        expect(rows.first[index], isNull);
      }
      expect(rows.first[firstDate.weekday - 1], firstDate);
      expect(rows.last[lastDate.weekday - 1], lastDate);
      for (var index = lastDate.weekday; index < 7; index += 1) {
        expect(rows.last[index], isNull);
      }
    },
  );
}

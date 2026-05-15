import 'package:flutter_test/flutter_test.dart';
import 'package:recordatorio/src/models/reminder.dart';
import 'package:recordatorio/src/utils/voice_reminder_creation.dart';
import 'package:recordatorio/src/utils/voice_reminder_parser.dart';

void main() {
  group('voice reminder quick create flow helpers', () {
    test('extrae solo el titulo de la primera respuesta', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      expect(
        extractVoiceReminderTitle(
          'Recordarme comprar pan manana a las 9',
          now: now,
        ),
        'Comprar pan',
      );
    });

    test('pule texto duplicado antes de crear el borrador', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = buildReminderDraftFromVoiceTranscript(
        'recordarme recuerdame llamar llamar al medico al medico manana a las 9 ok',
        now: now,
      );

      expect(draft.title, 'Llamar al medico');
      expect(draft.scheduledAt, DateTime(2026, 4, 8, 9, 0));
    });

    test('redacta un titulo limpio desde dictado con ecos separados', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = buildReminderDraftFromVoiceTranscript(
        'recordarme revisar factura manana revisar factura manana a las 9 ok',
        now: now,
      );

      expect(draft.title, 'Revisar factura');
      expect(draft.scheduledAt, DateTime(2026, 4, 8, 9, 0));
    });

    test('requiere fecha y hora completas en la segunda respuesta', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      expect(
        hasVoiceReminderCompleteSchedule('manana a las 9', now: now),
        isTrue,
      );
      expect(
        hasVoiceReminderCompleteSchedule('dentro de dos horas', now: now),
        isTrue,
      );
      expect(hasVoiceReminderCompleteSchedule('10 minutos', now: now), isTrue);
      expect(hasVoiceReminderCompleteSchedule('media hora', now: now), isTrue);
      expect(
        hasVoiceReminderCompleteSchedule('11 y 38 de la manana', now: now),
        isTrue,
      );
      expect(hasVoiceReminderCompleteSchedule('las 12 y 35', now: now), isTrue);
      expect(
        hasVoiceReminderCompleteSchedule(
          'cuatro y cincuenta y tres de la tarde',
          now: now,
        ),
        isTrue,
      );
      expect(hasVoiceReminderCompleteSchedule('manana', now: now), isFalse);
      expect(hasVoiceReminderCompleteSchedule('a las 9', now: now), isTrue);
    });

    test(
      'la segunda respuesta manda sobre una fecha accidental en la primera',
      () {
        final now = DateTime(2026, 4, 7, 10, 0);

        final draft = buildReminderDraftFromVoicePrompts(
          'Recordarme comprar pan manana a las 9',
          'el viernes a las 10',
          now: now,
        );

        expect(draft.title, 'Comprar pan');
        expect(draft.scheduledAt, DateTime(2026, 4, 10, 10, 0));
      },
    );

    test('acepta minutos como segunda respuesta de voz', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = buildReminderDraftFromVoicePrompts(
        'Recordarme comprar pan',
        '10 minutos',
        now: now,
      );

      expect(draft.title, 'Comprar pan');
      expect(draft.scheduledAt, DateTime(2026, 4, 7, 10, 10));
    });

    test('acepta hora militar desde horas habladas con minutos', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final morningDraft = buildReminderDraftFromVoicePrompts(
        'Recordarme comprar pan',
        '11 y 38 de la manana',
        now: now,
      );
      final afternoonDraft = buildReminderDraftFromVoicePrompts(
        'Recordarme comprar pan',
        '4 y 53 de la tarde',
        now: now,
      );
      final nightDraft = buildReminderDraftFromVoicePrompts(
        'Recordarme comprar pan',
        '9 y 18 de la noche',
        now: now,
      );

      expect(morningDraft.scheduledAt, DateTime(2026, 4, 7, 11, 38));
      expect(afternoonDraft.scheduledAt, DateTime(2026, 4, 7, 16, 53));
      expect(nightDraft.scheduledAt, DateTime(2026, 4, 7, 21, 18));
    });

    test('acepta segunda respuesta con variantes latinas', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = buildReminderDraftFromVoicePrompts(
        'Recordame comprar sinco kilos de arroz',
        'cuatro y cincuenta y tres de la tarde',
        now: now,
      );

      expect(draft.title, 'Comprar cinco kilos de arroz');
      expect(draft.scheduledAt, DateTime(2026, 4, 7, 16, 53));
    });

    test('acepta doce y treinta y cinco como segunda respuesta', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = buildReminderDraftFromVoicePrompts(
        'Recordame comprar pan',
        'las 12 y 35',
        now: now,
      );

      expect(draft.title, 'Comprar pan');
      expect(draft.scheduledAt, DateTime(2026, 4, 7, 12, 35));
    });

    test('crea borrador de tarea sin pedir fecha y hora', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = buildVoiceTaskDraft('tarea comprar pan', now: now);

      expect(isVoiceTaskCommand('tarea comprar pan'), isTrue);
      expect(draft.title, 'Comprar pan');
      expect(draft.kind, ReminderKind.task);
      expect(draft.hasSchedule, isFalse);
      expect(draft.scheduledAt, now);
    });

    test('crea borrador de lista de la compra con comando comprar', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = buildVoiceShoppingListDraft('comprar leche', now: now);

      expect(isVoiceShoppingListCommand('comprar leche'), isTrue);
      expect(draft.title, 'Leche');
      expect(draft.kind, ReminderKind.shoppingList);
      expect(draft.hasSchedule, isFalse);
      expect(draft.scheduledAt, now);
    });

    test('crea borrador de nota sin convertirla en tarea', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = buildVoiceNoteDraft('nota llamar a Juan', now: now);

      expect(isVoiceNoteCommand('nota llamar a Juan'), isTrue);
      expect(isVoiceTaskCommand('nota llamar a Juan'), isFalse);
      expect(draft.title, 'Llamar a juan');
      expect(draft.kind, ReminderKind.note);
      expect(draft.hasSchedule, isFalse);
      expect(draft.scheduledAt, now);
    });
  });
}

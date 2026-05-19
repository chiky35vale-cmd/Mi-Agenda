import 'package:flutter_test/flutter_test.dart';
import 'package:mi_agenda/src/models/reminder.dart';
import 'package:mi_agenda/src/utils/voice_reminder_parser.dart';

void main() {
  group('parseVoiceReminderCommand', () {
    test('detecta fecha, hora y repeticion semanal', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Recordarme llamar al dentista ma\u00f1ana a las 9 cada semana',
        now: now,
      );

      expect(draft.title, 'Llamar al dentista');
      expect(draft.repeatInterval, ReminderRepeatInterval.weekly);
      expect(
        draft.advanceReminderMinutes,
        defaultScheduledAdvanceReminderMinutes,
      );
      expect(draft.scheduledAt, DateTime(2026, 4, 8, 9, 0));
    });

    test('detecta aviso previo y repeticion diaria', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Comprar pan hoy a las 18 10 minutos antes cada dia',
        now: now,
      );

      expect(draft.title, 'Comprar pan');
      expect(draft.repeatInterval, ReminderRepeatInterval.daily);
      expect(draft.advanceReminderMinutes, 10);
      expect(draft.scheduledAt, DateTime(2026, 4, 7, 18, 0));
    });

    test('detecta repeticion mensual con dia natural', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Recu\u00e9rdame pagar el alquiler el d\u00eda 1 de cada mes a las 9',
        now: now,
      );

      expect(draft.title, 'Pagar el alquiler');
      expect(draft.repeatInterval, ReminderRepeatInterval.monthly);
      expect(draft.repeatSettings.monthDay, 1);
      expect(draft.scheduledAt, DateTime(2026, 5, 1, 9, 0));
    });

    test('detecta cada lunes como repeticion semanal', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Recu\u00e9rdame sacar la basura cada lunes a las 21',
        now: now,
      );

      expect(draft.title, 'Sacar la basura');
      expect(draft.repeatInterval, ReminderRepeatInterval.weekly);
      expect(draft.scheduledAt, DateTime(2026, 4, 13, 21, 0));
    });

    test('detecta proximo viernes por la tarde', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Recu\u00e9rdame recoger el pedido el pr\u00f3ximo viernes por la tarde',
        now: now,
      );

      expect(draft.title, 'Recoger el pedido');
      expect(draft.repeatInterval, ReminderRepeatInterval.none);
      expect(draft.scheduledAt, DateTime(2026, 4, 10, 18, 0));
    });

    test('detecta tiempo relativo dentro de dos horas', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Recu\u00e9rdame llamar a mam\u00e1 dentro de dos horas',
        now: now,
      );

      expect(draft.title, 'Llamar a mama');
      expect(draft.repeatInterval, ReminderRepeatInterval.none);
      expect(draft.scheduledAt, DateTime(2026, 4, 7, 12, 0));
    });

    test('detecta primer lunes de cada mes', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Recu\u00e9rdame pagar el alquiler el primer lunes de cada mes a las 9',
        now: now,
      );

      expect(draft.title, 'Pagar el alquiler');
      expect(draft.repeatInterval, ReminderRepeatInterval.monthly);
      expect(draft.repeatSettings.monthWeekOfMonth, 1);
      expect(draft.repeatSettings.monthWeekday, DateTime.monday);
      expect(draft.scheduledAt, DateTime(2026, 5, 4, 9, 0));
    });

    test('detecta ultimo viernes del mes como fecha natural', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Recu\u00e9rdame cerrar nominas el ultimo viernes del mes',
        now: now,
      );

      expect(draft.title, 'Cerrar nominas');
      expect(draft.repeatInterval, ReminderRepeatInterval.none);
      expect(draft.scheduledAt, DateTime(2026, 4, 24, 9, 0));
    });

    test('detecta ultimo viernes de cada mes como repeticion mensual', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Recu\u00e9rdame cerrar nominas el ultimo viernes de cada mes a las 18',
        now: now,
      );

      expect(draft.title, 'Cerrar nominas');
      expect(draft.repeatInterval, ReminderRepeatInterval.monthly);
      expect(draft.repeatSettings.monthWeekOfMonth, 5);
      expect(draft.repeatSettings.monthWeekday, DateTime.friday);
      expect(draft.scheduledAt, DateTime(2026, 4, 24, 18, 0));
    });

    test('detecta penultimo viernes del mes como fecha natural', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Recu\u00e9rdame revisar cuentas el penultimo viernes del mes',
        now: now,
      );

      expect(draft.title, 'Revisar cuentas');
      expect(draft.repeatInterval, ReminderRepeatInterval.none);
      expect(draft.scheduledAt, DateTime(2026, 4, 17, 9, 0));
    });

    test('detecta penultimo viernes de cada mes como repeticion mensual', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Recu\u00e9rdame revisar cuentas el penultimo viernes de cada mes a las 18',
        now: now,
      );

      expect(draft.title, 'Revisar cuentas');
      expect(draft.repeatInterval, ReminderRepeatInterval.monthly);
      expect(draft.repeatSettings.monthWeekFromEnd, 2);
      expect(draft.repeatSettings.monthWeekday, DateTime.friday);
      expect(draft.scheduledAt, DateTime(2026, 4, 17, 18, 0));
    });

    test('detecta manana por la noche', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Recu\u00e9rdame llamar a Laura ma\u00f1ana por la noche',
        now: now,
      );

      expect(draft.title, 'Llamar a laura');
      expect(draft.scheduledAt, DateTime(2026, 4, 8, 21, 0));
    });

    test('ignora de la manana como parte del mensaje', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Recu\u00e9rdame llamar al banco ma\u00f1ana de la ma\u00f1ana',
        now: now,
      );

      expect(draft.title, 'Llamar al banco');
      expect(draft.scheduledAt, DateTime(2026, 4, 8, 9, 0));
    });

    test('ignora de la tarde como parte del mensaje', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Recu\u00e9rdame revisar presupuesto el viernes de la tarde',
        now: now,
      );

      expect(draft.title, 'Revisar presupuesto');
      expect(draft.scheduledAt, DateTime(2026, 4, 10, 18, 0));
    });

    test('detecta dentro de media hora', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Recu\u00e9rdame revisar el horno dentro de media hora',
        now: now,
      );

      expect(draft.title, 'Revisar el horno');
      expect(draft.scheduledAt, DateTime(2026, 4, 7, 10, 30));
    });

    test('detecta dentro de 90 minutos', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Recu\u00e9rdame revisar el horno dentro de 90 minutos',
        now: now,
      );

      expect(draft.title, 'Revisar el horno');
      expect(draft.scheduledAt, DateTime(2026, 4, 7, 11, 30));
    });

    test('detecta minutos sin prefijo en la respuesta de fecha y hora', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Comprar pan 10 minutos',
        now: now,
      );

      expect(draft.title, 'Comprar pan');
      expect(draft.scheduledAt, DateTime(2026, 4, 7, 10, 10));
    });

    test('detecta hora hablada con minutos y periodo del dia', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final morningDraft = parseVoiceReminderCommand(
        'Comprar pan 11 y 38 de la manana',
        now: now,
      );
      final afternoonDraft = parseVoiceReminderCommand(
        'Comprar pan 4 y 53 de la tarde',
        now: now,
      );
      final nightDraft = parseVoiceReminderCommand(
        'Comprar pan 9 y 18 de la noche',
        now: now,
      );
      final spokenMinuteDraft = parseVoiceReminderCommand(
        'Comprar pan 4 y cincuenta y tres de la tarde',
        now: now,
      );

      expect(morningDraft.title, 'Comprar pan');
      expect(morningDraft.scheduledAt, DateTime(2026, 4, 7, 11, 38));
      expect(afternoonDraft.scheduledAt, DateTime(2026, 4, 7, 16, 53));
      expect(nightDraft.scheduledAt, DateTime(2026, 4, 7, 21, 18));
      expect(spokenMinuteDraft.scheduledAt, DateTime(2026, 4, 7, 16, 53));
    });

    test('detecta hora hablada con minutos sin periodo del dia', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final numericDraft = parseVoiceReminderCommand(
        'Comprar pan las 12 y 35',
        now: now,
      );
      final bareNumericDraft = parseVoiceReminderCommand(
        'Comprar pan 12 y 35',
        now: now,
      );
      final spokenDraft = parseVoiceReminderCommand(
        'Comprar pan las doce y treinta y cinco',
        now: now,
      );
      final tomorrowDraft = parseVoiceReminderCommand(
        'Comprar pan las 12 y 35',
        now: DateTime(2026, 4, 7, 13, 0),
      );

      expect(numericDraft.title, 'Comprar pan');
      expect(numericDraft.scheduledAt, DateTime(2026, 4, 7, 12, 35));
      expect(bareNumericDraft.scheduledAt, DateTime(2026, 4, 7, 12, 35));
      expect(spokenDraft.scheduledAt, DateTime(2026, 4, 7, 12, 35));
      expect(tomorrowDraft.scheduledAt, DateTime(2026, 4, 8, 12, 35));
    });

    test('entiende variantes castellanas y latinas con seseo y ene', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final tomorrowDraft = parseVoiceReminderCommand(
        'Recordame llamar a mama maniana en la tarde',
        now: now,
      );
      final shoppingDraft = parseVoiceReminderCommand(
        'Avisame comprar sinco kilos de arroz para las cuatro y cincuenta y tres de la tarde',
        now: now,
      );
      final nextFridayDraft = parseVoiceReminderCommand(
        'Agendame cita el prosimo viernes a las onse de la noche',
        now: now,
      );
      final monthDraft = parseVoiceReminderCommand(
        'Programame pagar la luz el quinze de abril a las ocho en la noche',
        now: now,
      );
      final colonDraft = parseVoiceReminderCommand(
        'Ponme revisar informe 9:18 en la noche',
        now: now,
      );

      expect(tomorrowDraft.title, 'Llamar a mama');
      expect(tomorrowDraft.scheduledAt, DateTime(2026, 4, 8, 18, 0));
      expect(shoppingDraft.title, 'Comprar cinco kilos de arroz');
      expect(shoppingDraft.scheduledAt, DateTime(2026, 4, 7, 16, 53));
      expect(nextFridayDraft.title, 'Cita');
      expect(nextFridayDraft.scheduledAt, DateTime(2026, 4, 10, 23, 0));
      expect(monthDraft.title, 'Pagar la luz');
      expect(monthDraft.scheduledAt, DateTime(2026, 4, 15, 20, 0));
      expect(colonDraft.title, 'Revisar informe');
      expect(colonDraft.scheduledAt, DateTime(2026, 4, 7, 21, 18));
    });

    test('detecta en hora y media', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Recu\u00e9rdame revisar el horno en hora y media',
        now: now,
      );

      expect(draft.title, 'Revisar el horno');
      expect(draft.scheduledAt, DateTime(2026, 4, 7, 11, 30));
    });

    test('detecta dentro de 2 horas y media', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Recu\u00e9rdame revisar el horno dentro de 2 horas y media',
        now: now,
      );

      expect(draft.title, 'Revisar el horno');
      expect(draft.scheduledAt, DateTime(2026, 4, 7, 12, 30));
    });

    test('detecta pasado manana a primera hora', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Recu\u00e9rdame llamar al taller pasado ma\u00f1ana a primera hora',
        now: now,
      );

      expect(draft.title, 'Llamar al taller');
      expect(draft.scheduledAt, DateTime(2026, 4, 9, 8, 0));
    });

    test('detecta a final de mes', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final draft = parseVoiceReminderCommand(
        'Recu\u00e9rdame enviar la factura a final de mes',
        now: now,
      );

      expect(draft.title, 'Enviar la factura');
      expect(draft.scheduledAt, DateTime(2026, 4, 30, 9, 0));
    });
  });

  group('parseVoiceReminderEditCommand', () {
    test('detecta numero y nueva hora por voz', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final command = parseVoiceReminderEditCommand(
        'editar recordatorio 2 a las 12 y 35',
        now: now,
      );

      expect(command, isNotNull);
      expect(command!.reminderNumber, 2);
      expect(command.title, isNull);
      expect(command.scheduledAt, DateTime(2026, 4, 7, 12, 35));
      expect(command.hasChanges, isTrue);
    });

    test('permite abrir la edicion diciendo solo el numero', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final command = parseVoiceReminderEditCommand(
        'editar recordatorio 2',
        now: now,
      );

      expect(command, isNotNull);
      expect(command!.reminderNumber, 2);
      expect(command.hasChanges, isFalse);
    });

    test('detecta variantes de numero de recordatorio por voz', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final numberBeforeReminder = parseVoiceReminderEditCommand(
        'editar numero de recordatorio dos',
        now: now,
      );
      final ordinalBeforeReminder = parseVoiceReminderEditCommand(
        'editar el segundo recordatorio',
        now: now,
      );
      final ordinalAfterReminder = parseVoiceReminderEditCommand(
        'modifica aviso tercero a las 18',
        now: now,
      );

      expect(numberBeforeReminder, isNotNull);
      expect(numberBeforeReminder!.reminderNumber, 2);
      expect(ordinalBeforeReminder, isNotNull);
      expect(ordinalBeforeReminder!.reminderNumber, 2);
      expect(ordinalAfterReminder, isNotNull);
      expect(ordinalAfterReminder!.reminderNumber, 3);
      expect(ordinalAfterReminder.scheduledAt, DateTime(2026, 4, 7, 18, 0));
    });

    test('detecta titulo y mantiene campos no mencionados como nulos', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final command = parseVoiceReminderEditCommand(
        'cambiar el 1 titulo comprar pan',
        now: now,
      );

      expect(command, isNotNull);
      expect(command!.reminderNumber, 1);
      expect(command.title, 'Comprar pan');
      expect(command.scheduledAt, isNull);
      expect(command.advanceReminderMinutes, isNull);
      expect(command.repeatInterval, isNull);
    });

    test('detecta repeticion diaria en comando de edicion', () {
      final now = DateTime(2026, 4, 7, 10, 0);

      final command = parseVoiceReminderEditCommand(
        'actualiza aviso tres manana a las nueve cada dia',
        now: now,
      );

      expect(command, isNotNull);
      expect(command!.reminderNumber, 3);
      expect(command.scheduledAt, DateTime(2026, 4, 8, 9, 0));
      expect(command.repeatInterval, ReminderRepeatInterval.daily);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_agenda/src/utils/voice_text_polisher.dart';

void main() {
  group('polishVoiceTranscriptText', () {
    test('elimina palabras duplicadas y comandos repetidos', () {
      expect(
        polishVoiceTranscriptText(
          'recordarme recuerdame llamar llamar al medico manana a las 9 ok',
        ),
        'Recordarme llamar al medico manana a las 9',
      );
    });

    test('elimina bloques repetidos por solapamiento de dictado', () {
      expect(
        polishVoiceTranscriptText(
          'recordarme comprar pan comprar pan manana manana a las 9',
        ),
        'Recordarme comprar pan manana a las 9',
      );
    });

    test('elimina repeticiones separadas de una misma idea', () {
      expect(
        polishVoiceTranscriptText(
          'recordarme revisar factura manana revisar factura manana a las 9',
        ),
        'Recordarme revisar factura manana a las 9',
      );
    });

    test('usa memoria de vocabulario para respetar palabras frecuentes', () {
      final memory = VoiceVocabularyMemory.fromTexts(<String>[
        'Llamar a Maria Jose',
      ]);

      expect(
        polishVoiceTranscriptText(
          'recordarme llamar a maria jose llamar a maria jose manana',
          vocabularyMemory: memory,
        ),
        'Recordarme llamar a Maria Jose manana',
      );
    });
  });

  group('polishVoiceTitleText', () {
    test('devuelve un titulo presentable', () {
      expect(polishVoiceTitleText('comprar pan comprar pan'), 'Comprar pan');
    });

    test('elimina conectores sueltos de la hora al final', () {
      expect(polishVoiceTitleText('llamar al banco de la'), 'Llamar al banco');
    });
  });
}

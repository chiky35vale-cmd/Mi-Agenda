import 'package:flutter_test/flutter_test.dart';
import 'package:mi_agenda/src/utils/voice_dictation.dart';

void main() {
  group('voice dictation helpers', () {
    test('detecta el terminador ok al final', () {
      expect(
        hasVoiceDictationTerminator('Recordarme llamar al medico manana ok'),
        isTrue,
      );
      expect(
        hasVoiceDictationTerminator(
          'Recordarme llamar al medico manana \u00bfOK?',
        ),
        isTrue,
      );
    });

    test('limpia el terminador ok antes de crear el recordatorio', () {
      expect(
        sanitizeVoiceDictationTranscript(
          'Recordarme llamar al medico manana a las 9 \u00bfOK?',
        ),
        'Recordarme llamar al medico manana a las 9',
      );
    });

    test('une fragmentos de dictado sin duplicarlos', () {
      expect(
        mergeVoiceDictationTranscript(
          'Recordarme llamar al medico',
          'manana a las 9',
        ),
        'Recordarme llamar al medico manana a las 9',
      );
      expect(
        mergeVoiceDictationTranscript(
          'Recordarme llamar al medico',
          'Recordarme llamar al medico manana',
        ),
        'Recordarme llamar al medico manana',
      );
      expect(
        mergeVoiceDictationTranscript(
          'Recordarme comprar pan',
          'comprar pan manana a las 9',
        ),
        'Recordarme comprar pan manana a las 9',
      );
    });
  });
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_agenda/src/app/mi_agenda_app.dart';

void main() {
  group('resolveAppInitialRoute', () {
    test('respeta la ruta nativa para crear por voz', () {
      expect(
        resolveAppInitialRoute(
          platformRoute: '/voice-quick-create',
          pendingReminderOpenId: null,
        ),
        '/voice-quick-create',
      );
    });

    test('abre la lista si llega una peticion pendiente desde notificacion', () {
      expect(
        resolveAppInitialRoute(
          platformRoute: Navigator.defaultRouteName,
          pendingReminderOpenId: 42,
        ),
        '/list',
      );
    });

    test('mantiene la ruta normal cuando no hay desvio especial', () {
      expect(
        resolveAppInitialRoute(
          platformRoute: Navigator.defaultRouteName,
          pendingReminderOpenId: null,
        ),
        Navigator.defaultRouteName,
      );
    });
  });
}

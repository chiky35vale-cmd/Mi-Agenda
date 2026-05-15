import 'package:flutter/services.dart';

class VoiceConfirmationService {
  VoiceConfirmationService._();

  static const MethodChannel _channel = MethodChannel(
    'com.tunombre.recordatorio/voice_confirmation',
  );

  static Future<void> askForDateAndTime() async {
    await speakText('\u00bfFecha y hora?');
  }

  static Future<void> speakReminderCreated(String title) async {
    final cleanedTitle = title.trim();
    if (cleanedTitle.isEmpty) {
      return;
    }

    await speakText('Recordatorio creado. $cleanedTitle.');
  }

  static Future<void> speakTaskCreated(String title) async {
    final cleanedTitle = title.trim();
    if (cleanedTitle.isEmpty) {
      return;
    }

    await speakText('Tarea creada. $cleanedTitle.');
  }

  static Future<void> speakShoppingListItemCreated(String title) async {
    final cleanedTitle = title.trim();
    if (cleanedTitle.isEmpty) {
      return;
    }

    await speakText('Anotado en la lista de la compra. $cleanedTitle.');
  }

  static Future<void> speakNoteCreated(String title) async {
    final cleanedTitle = title.trim();
    if (cleanedTitle.isEmpty) {
      return;
    }

    await speakText('Nota guardada. $cleanedTitle.');
  }

  static Future<void> speakText(String text) async {
    final cleanedText = text.trim();
    if (cleanedText.isEmpty) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('speakConfirmation', <String, Object?>{
        'text': cleanedText,
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}

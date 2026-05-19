import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'src/app/mi_agenda_app.dart';
import 'src/controllers/reminder_controller.dart';
import 'src/data/reminder_repository.dart';
import 'src/services/reminder_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'es_ES';
  await initializeDateFormatting('es_ES');

  final repository = SqfliteReminderRepository();
  await repository.initialize();

  final notificationService = LocalReminderNotificationService();
  await notificationService.initialize();

  final controller = ReminderController(
    repository: repository,
    notificationService: notificationService,
  );
  notificationService.setOnReminderChangedCallback(controller.refresh);
  notificationService.setOnOpenReminderRequestedCallback(
    controller.requestReminderOpen,
  );
  await controller.initialize();

  runApp(MiAgendaApp(controller: controller));
}

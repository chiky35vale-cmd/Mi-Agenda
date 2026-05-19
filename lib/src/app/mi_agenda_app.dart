import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../controllers/reminder_controller.dart';
import '../screens/home_screen.dart';
import '../screens/voice_quick_create_screen.dart';
import 'app_theme.dart';

class MiAgendaApp extends StatefulWidget {
  const MiAgendaApp({super.key, required this.controller});

  final ReminderController controller;

  @override
  State<MiAgendaApp> createState() => _MiAgendaAppState();
}

class _MiAgendaAppState extends State<MiAgendaApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  int _lastHandledReminderOpenRequest = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant MiAgendaApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }

    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialRoute = resolveAppInitialRoute(
      platformRoute: WidgetsBinding.instance.platformDispatcher.defaultRouteName,
      pendingReminderOpenId: widget.controller.pendingReminderOpenId,
    );

    return ChangeNotifierProvider<ReminderController>.value(
      value: widget.controller,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Mi Agenda',
        theme: buildAppTheme(),
        locale: const Locale('es', 'ES'),
        supportedLocales: const <Locale>[Locale('es', 'ES')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        initialRoute: initialRoute,
        routes: <String, WidgetBuilder>{
          '/': (_) => const HomeScreen(),
          '/list': (_) => const HomeScreen(),
          '/voice-quick-create': (_) => const VoiceQuickCreateScreen(),
        },
      ),
    );
  }

  void _handleControllerChanged() {
    final pendingReminderId = widget.controller.pendingReminderOpenId;
    final pendingRequest = widget.controller.pendingReminderOpenRequest;
    if (pendingReminderId == null ||
        pendingRequest == _lastHandledReminderOpenRequest) {
      return;
    }

    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _handleControllerChanged();
        }
      });
      return;
    }

    _lastHandledReminderOpenRequest = pendingRequest;
    navigator.pushNamedAndRemoveUntil('/list', (route) => false);
  }
}

String resolveAppInitialRoute({
  required String platformRoute,
  required int? pendingReminderOpenId,
}) {
  final normalizedPlatformRoute = platformRoute.trim();
  if (normalizedPlatformRoute.isNotEmpty &&
      normalizedPlatformRoute != Navigator.defaultRouteName) {
    return normalizedPlatformRoute;
  }

  if (pendingReminderOpenId != null) {
    return '/list';
  }

  return Navigator.defaultRouteName;
}

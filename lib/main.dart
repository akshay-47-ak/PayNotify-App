import 'package:flutter/material.dart';

import 'models/device_session.dart';
import 'pages/login_page.dart';
import 'pages/notification_log_page.dart';
import 'pages/qr_display_page.dart';
import 'pages/registration_page.dart';
import 'pages/splash_page.dart';
import 'services/session_service.dart';
import 'ui/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("Flutter UI Error: ${details.exception}");
    debugPrint(details.stack.toString());
  };

  runApp(const MyApp());
}

class AppRoutes {
  static const String splash = "/";
  static const String login = "/login";
  static const String register = "/register";
  static const String qrDisplay = "/qr-display";
  static const String notificationLog = "/notification-log";
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  DeviceSession? session;
  bool isSessionLoading = true;
  String errorMessage = "";

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSession();
    });
  }

  Future<void> _loadSession() async {
    try {
      final savedSession = await SessionService.getSession();

      if (!mounted) return;

      setState(() {
        session = savedSession;
        isSessionLoading = false;
      });
    } catch (e) {
      debugPrint("Session load error: $e");

      if (!mounted) return;

      setState(() {
        session = null;
        errorMessage = e.toString();
        isSessionLoading = false;
      });
    }
  }

  void _onLoginSuccess(DeviceSession newSession) {
    setState(() {
      session = newSession;
    });

    _navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.qrDisplay,
      (route) => false,
    );
  }

  void _onRegistered(DeviceSession newSession) {
    setState(() {
      session = newSession;
    });

    _navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.qrDisplay,
      (route) => false,
    );
  }

  void _onClearSession() {
    setState(() {
      session = null;
    });

    _navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  void _goToRegistration() {
    _navigatorKey.currentState?.pushNamed(AppRoutes.register);
  }

  void _goToLogin() {
    _navigatorKey.currentState?.pushNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'PayNotify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (context) => SplashPage(
          isLoading: isSessionLoading,
          onLogin: () => Navigator.of(context).pushNamed(AppRoutes.login),
          onRegister: () => Navigator.of(context).pushNamed(AppRoutes.register),
        ),
        AppRoutes.login: (context) => LoginPage(
          onLoginSuccess: _onLoginSuccess,
          onGoToRegistration: _goToRegistration,
        ),
        AppRoutes.register: (context) => RegistrationPage(
          onRegistered: _onRegistered,
          onGoToLogin: _goToLogin,
        ),
        AppRoutes.qrDisplay: (context) {
          final activeSession = session;

          if (isSessionLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (activeSession == null) {
            return _SessionRequiredPage(errorMessage: errorMessage);
          }

          return QrDisplayPage(
            session: activeSession,
            onClearSession: _onClearSession,
          );
        },
        AppRoutes.notificationLog: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final logs = args is List<String> ? args : <String>[];

          return NotificationLogPage(logs: logs);
        },
      },
    );
  }
}

class _SessionRequiredPage extends StatelessWidget {
  final String errorMessage;

  const _SessionRequiredPage({required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Session Required")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              errorMessage.isEmpty
                  ? "Session not found. Please login again."
                  : errorMessage,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false),
              child: const Text("Go to Login"),
            ),
          ],
        ),
      ),
    );
  }
}

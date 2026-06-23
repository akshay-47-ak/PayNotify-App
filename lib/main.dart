import 'package:flutter/material.dart';

import 'models/device_session.dart';
import 'pages/login_page.dart';
import 'pages/qr_display_page.dart';
import 'pages/registration_page.dart';
import 'services/session_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("Flutter UI Error: ${details.exception}");
    debugPrint(details.stack.toString());
  };

  runApp(const MyApp());
}

enum AppPage { loading, login, registration, qrPayment }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PayNotify',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const AppStartPage(),
    );
  }
}

class AppStartPage extends StatefulWidget {
  const AppStartPage({super.key});

  @override
  State<AppStartPage> createState() => _AppStartPageState();
}

class _AppStartPageState extends State<AppStartPage> {
  AppPage currentPage = AppPage.loading;
  DeviceSession? session;
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

        if (savedSession == null) {
          currentPage = AppPage.login;
        } else {
          currentPage = AppPage.qrPayment;
        }
      });
    } catch (e) {
      debugPrint("Session load error: $e");

      if (!mounted) return;

      setState(() {
        session = null;
        errorMessage = e.toString();
        currentPage = AppPage.login;
      });
    }
  }

  void _onLoginSuccess(DeviceSession newSession) {
    setState(() {
      session = newSession;
      currentPage = AppPage.qrPayment;
    });
  }

  void _onRegistered(DeviceSession newSession) {
    setState(() {
      session = newSession;
      currentPage = AppPage.qrPayment;
    });
  }

  void _onClearSession() {
    setState(() {
      session = null;
      currentPage = AppPage.login;
    });
  }

  void _goToRegistration() {
    setState(() {
      currentPage = AppPage.registration;
    });
  }

  void _goToLogin() {
    setState(() {
      currentPage = AppPage.login;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentPage == AppPage.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (currentPage == AppPage.login) {
      return LoginPage(
        onLoginSuccess: _onLoginSuccess,
        onGoToRegistration: _goToRegistration,
      );
    }

    if (currentPage == AppPage.registration) {
      return RegistrationPage(
        onRegistered: _onRegistered,
        onGoToLogin: _goToLogin,
      );
    }

    if (currentPage == AppPage.qrPayment && session != null) {
      return QrDisplayPage(session: session!, onClearSession: _onClearSession);
    }

    return Scaffold(
      appBar: AppBar(title: const Text("App Error")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          errorMessage.isEmpty
              ? "Session not found. Please login again."
              : errorMessage,
        ),
      ),
    );
  }
}

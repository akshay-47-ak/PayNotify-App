import 'package:flutter/material.dart';

import 'models/device_session.dart';
import 'pages/qr_display_page.dart';
import 'pages/registration_page.dart';
import 'services/session_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pay Alert Bridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
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
  bool isLoading = true;
  DeviceSession? session;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final savedSession = await SessionService.getSession();

    if (!mounted) return;

    setState(() {
      session = savedSession;
      isLoading = false;
    });
  }

  void _onRegistered(DeviceSession newSession) {
    setState(() {
      session = newSession;
    });
  }

  void _onClearSession() {
    setState(() {
      session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (session == null) {
      return RegistrationPage(
        onRegistered: _onRegistered,
      );
    }

    return QrDisplayPage(
      session: session!,
      onClearSession: _onClearSession,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pay_notify/pages/splash_page.dart';

void main() {
  testWidgets('Splash page shows login and registration actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashPage(onLogin: () {}, onRegister: () {}),
      ),
    );

    expect(find.text('PayNotify'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Register Device'),
      findsOneWidget,
    );
  });
}

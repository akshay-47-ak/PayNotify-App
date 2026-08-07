import 'package:flutter_test/flutter_test.dart';
import 'package:pay_notify/models/payment_notify_request.dart';
import 'package:pay_notify/models/payment_notification.dart';
import 'package:pay_notify/services/notification_handler.dart';

void main() {
  test(
    'payment notification payload matches backend LocalDateTime contract',
    () {
      final receivedAt = NotificationHandler.backendLocalDateTime(
        DateTime(2026, 7, 11, 14, 30, 45, 123),
      );

      final request = PaymentNotifyRequest(
        enterpriseCode: 'PADM001',
        deviceIdentifier: 'device-1',
        terminalId: 'TERM-1',
        appName: NotificationHandler.appNameForPackage('com.phonepe.app'),
        packageName: 'com.phonepe.app',
        title: 'Payment received',
        message: 'Rahul paid you Rs. 500.00',
        rawTitle: 'Payment received',
        rawMessage: 'Rahul paid you Rs. 500.00',
        amount: 500,
        payerName: 'Rahul',
        extractedTxnId: null,
        notificationReceivedAt: receivedAt,
        transactionRef: null,
      );

      final json = request.toJson();

      expect(json['appName'], 'PHONEPE');
      expect(json['notificationReceivedAt'], '2026-07-11T14:30:45.123');
      expect(json['notificationReceivedAt'], isA<String>());
    },
  );

  test('Google Pay package maps to backend enum value', () {
    expect(
      NotificationHandler.appNameForPackage(
        'com.google.android.apps.nbu.paisa.user',
      ),
      'GOOGLE_PAY',
    );
  });

  test('variant package names still map to backend payment app values', () {
    expect(
      NotificationHandler.appNameForPackage('com.phonepe.app.business'),
      'PHONEPE',
    );
    expect(
      NotificationHandler.appNameForPackage('com.example.gpay'),
      'GOOGLE_PAY',
    );
  });

  test('notification post timestamp is used for backend received time', () {
    final notification = PaymentNotification(
      packageName: 'com.phonepe.app',
      title: 'Payment received',
      text: 'Rahul paid you Rs. 500.00',
      timestamp: DateTime(2026, 7, 11, 14, 30, 45, 123).millisecondsSinceEpoch,
    );

    expect(
      NotificationHandler.backendLocalDateTime(
        NotificationHandler.notificationDateTime(notification),
      ),
      '2026-07-11T14:30:45.123',
    );
  });

  test('PhonePe grouped completed updates split into separate notifications', () {
    final notification = PaymentNotification(
      packageName: 'com.phonepe.app',
      title: '2 new completed transaction updates',
      text:
          '⋅ AAYAN JAVID SAYYAD has sent ₹2 to your bank account Bank Of Maharashtra-4875\n'
          '⋅ SOHAM ANIL SHENDE has sent ₹1 to your bank account Bank Of Maharashtra-4875',
      bigText:
          '⋅ AAYAN JAVID SAYYAD has sent ₹2 to your bank account Bank Of Maharashtra-4875\n'
          '⋅ SOHAM ANIL SHENDE has sent ₹1 to your bank account Bank Of Maharashtra-4875',
      timestamp: DateTime(2026, 8, 7, 12, 12, 27).millisecondsSinceEpoch,
    );

    final expanded = NotificationHandler.expandNotificationsForProcessing(
      notification,
    );

    expect(expanded, hasLength(2));
    expect(expanded[0].title, 'PhonePe payment received');
    expect(
      expanded[0].text,
      'AAYAN JAVID SAYYAD has sent ₹2 to your bank account Bank Of Maharashtra-4875',
    );
    expect(
      expanded[1].text,
      'SOHAM ANIL SHENDE has sent ₹1 to your bank account Bank Of Maharashtra-4875',
    );
    expect(NotificationHandler.extractAmount(expanded[0].text), 2);
    expect(NotificationHandler.extractAmount(expanded[1].text), 1);
    expect(
      NotificationHandler.extractPayerName(expanded[0].text),
      'AAYAN JAVID SAYYAD',
    );
  });

  test('PhonePe grouped plus more line is not converted into fake payment', () {
    final notification = PaymentNotification(
      packageName: 'com.phonepe.app',
      title: '3 new completed transaction updates',
      text:
          '⋅ AAYAN JAVID SAYYAD has sent ₹2 to your bank account Bank Of Maharashtra-4875\n'
          '⋅ SOHAM ANIL SHENDE has sent ₹1 to your bank account Bank Of Maharashtra-4875\n'
          '+ 1 more',
    );

    final expanded = NotificationHandler.expandNotificationsForProcessing(
      notification,
    );

    expect(expanded, hasLength(2));
    expect(expanded.any((item) => item.text.contains('+ 1 more')), isFalse);
  });

  test('PhonePe grouped update can split many visible payment lines', () {
    final lines = List.generate(
      10,
      (index) =>
          '⋅ PAYER ${index + 1} has sent ₹${index + 1} to your bank account Bank Of Maharashtra-4875',
    );
    final notification = PaymentNotification(
      packageName: 'com.phonepe.app',
      title: '10 new completed transaction updates',
      text: lines.join('\n'),
      bigText: lines.join('\n'),
    );

    final expanded = NotificationHandler.expandNotificationsForProcessing(
      notification,
    );

    expect(expanded, hasLength(10));
    expect(expanded.first.text, contains('PAYER 1 has sent ₹1'));
    expect(expanded.last.text, contains('PAYER 10 has sent ₹10'));
  });

  test('Google Pay notifications are not split', () {
    final notification = PaymentNotification(
      packageName: 'com.google.android.apps.nbu.paisa.user',
      title: '2 new completed transaction updates',
      text:
          'A paid you Rs. 2\n'
          'B paid you Rs. 1',
    );

    final expanded = NotificationHandler.expandNotificationsForProcessing(
      notification,
    );

    expect(expanded, hasLength(1));
    expect(identical(expanded.first, notification), isTrue);
  });
}

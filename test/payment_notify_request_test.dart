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
}

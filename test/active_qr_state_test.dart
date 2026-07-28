import 'package:flutter_test/flutter_test.dart';
import 'package:pay_notify/models/active_qr_state.dart';

void main() {
  test('active QR state preserves terminal QR payload fields', () {
    final state = ActiveQrState(
      paymentId: 'PAY-1',
      transactionRef: 'PADM-TXN-1',
      status: 'WAITING',
      qrImageBase64: 'data:image/png;base64,abc',
      generatedAtMillis: 1785225600000,
    );

    final restored = ActiveQrState.fromJson(state.toJson());

    expect(restored.paymentId, 'PAY-1');
    expect(restored.transactionRef, 'PADM-TXN-1');
    expect(restored.status, 'WAITING');
    expect(restored.qrImageBase64, 'data:image/png;base64,abc');
    expect(restored.generatedAtMillis, 1785225600000);
  });
}

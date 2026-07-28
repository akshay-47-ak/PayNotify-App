import 'package:flutter_test/flutter_test.dart';
import 'package:pay_notify/models/device_registration_response.dart';
import 'package:pay_notify/models/device_session.dart';
import 'package:pay_notify/models/enterprise_validation_response.dart';

void main() {
  test('device registration response reads mobile JWT fields', () {
    final response = DeviceRegistrationResponse.fromJson({
      'deviceId': 1,
      'enterpriseCode': 'PADM001',
      'enterpriseName': 'PADM Enterprise',
      'role': 'CASHIER',
      'terminalId': 'TERM-1',
      'deviceIdentifier': 'device-1',
      'deviceName': 'Counter 1',
      'status': 'REGISTERED',
      'token': 'jwt-token',
      'tokenExpiresAt': 1785225600000,
      'tokenType': 'Bearer',
    });

    expect(response.token, 'jwt-token');
    expect(response.tokenExpiresAt, 1785225600000);
    expect(response.tokenType, 'Bearer');
  });

  test('device session persists mobile JWT fields', () {
    final session = DeviceSession(
      enterpriseCode: 'PADM001',
      enterpriseName: 'PADM Enterprise',
      role: 'CASHIER',
      terminalId: 'TERM-1',
      deviceIdentifier: 'device-1',
      deviceName: 'Counter 1',
      token: 'jwt-token',
      tokenExpiresAt: 1785225600000,
      tokenType: 'Bearer',
    );

    final restored = DeviceSession.fromJson(session.toJson());

    expect(restored.token, 'jwt-token');
    expect(restored.tokenExpiresAt, 1785225600000);
    expect(restored.tokenType, 'Bearer');
  });

  test('enterprise validation response reads web cashier JWT fields', () {
    final response = EnterpriseValidationResponse.fromJson({
      'valid': true,
      'enterpriseCode': 'PADM001',
      'enterpriseName': 'PADM Enterprise',
      'department': 'PADM',
      'departmentCode': 1,
      'status': 'VALID',
      'message': 'Enterprise validated successfully',
      'token': 'web-jwt-token',
      'tokenExpiresAt': 1785225600000,
      'tokenType': 'Bearer',
    });

    expect(response.token, 'web-jwt-token');
    expect(response.tokenExpiresAt, 1785225600000);
    expect(response.tokenType, 'Bearer');
  });
}

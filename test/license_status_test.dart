import 'package:flutter_test/flutter_test.dart';
import 'package:fidelio/domain/entities/license_status.dart';

void main() {
  group('LicenseStatus.isExpiringSoon', () {
    test('false when state is invalid', () {
      const status = LicenseStatus(
        state: LicenseState.invalid,
        message: 'invalid',
        isLifetime: false,
        daysUntilExpiry: 5,
      );
      expect(status.isExpiringSoon, isFalse);
    });

    test('false when state is missing', () {
      const status = LicenseStatus(
        state: LicenseState.missing,
        message: 'missing',
        isLifetime: false,
        daysUntilExpiry: 3,
      );
      expect(status.isExpiringSoon, isFalse);
    });

    test('false when isLifetime is true', () {
      const status = LicenseStatus(
        state: LicenseState.active,
        message: 'active',
        isLifetime: true,
        daysUntilExpiry: 5,
      );
      expect(status.isExpiringSoon, isFalse);
    });

    test('false when isLifetime is null (treat as permanent)', () {
      const status = LicenseStatus(
        state: LicenseState.active,
        message: 'active',
        daysUntilExpiry: 5,
      );
      expect(status.isExpiringSoon, isFalse);
    });

    test('false when daysUntilExpiry is null', () {
      const status = LicenseStatus(
        state: LicenseState.active,
        message: 'active',
        isLifetime: false,
      );
      expect(status.isExpiringSoon, isFalse);
    });

    test('false when daysUntilExpiry is 11', () {
      const status = LicenseStatus(
        state: LicenseState.active,
        message: 'active',
        isLifetime: false,
        daysUntilExpiry: 11,
      );
      expect(status.isExpiringSoon, isFalse);
    });

    test('true when daysUntilExpiry is exactly 10', () {
      const status = LicenseStatus(
        state: LicenseState.active,
        message: 'active',
        isLifetime: false,
        daysUntilExpiry: 10,
      );
      expect(status.isExpiringSoon, isTrue);
    });

    test('true when daysUntilExpiry is 5', () {
      const status = LicenseStatus(
        state: LicenseState.active,
        message: 'active',
        isLifetime: false,
        daysUntilExpiry: 5,
      );
      expect(status.isExpiringSoon, isTrue);
    });

    test('true when daysUntilExpiry is 1', () {
      const status = LicenseStatus(
        state: LicenseState.active,
        message: 'active',
        isLifetime: false,
        daysUntilExpiry: 1,
      );
      expect(status.isExpiringSoon, isTrue);
    });
  });

  group('LicenseStatus.fromJson', () {
    test('parses active lifetime license', () {
      final status = LicenseStatus.fromJson({
        'status': 'active',
        'message': 'Lifetime license active.',
        'licenseId': 'lic-123',
        'stickId': 'stick-456',
        'isLifetime': true,
      });

      expect(status.state, LicenseState.active);
      expect(status.isActive, isTrue);
      expect(status.isLifetime, isTrue);
      expect(status.daysUntilExpiry, isNull);
      expect(status.validUntil, isNull);
      expect(status.isExpiringSoon, isFalse);
    });

    test('parses active expiring license within warning window', () {
      final status = LicenseStatus.fromJson({
        'status': 'active',
        'message': 'License active. 5 days remaining.',
        'licenseId': 'lic-123',
        'stickId': 'stick-456',
        'isLifetime': false,
        'daysUntilExpiry': 5,
        'validUntil': '2026-06-29T00:00:00Z',
      });

      expect(status.state, LicenseState.active);
      expect(status.isLifetime, isFalse);
      expect(status.daysUntilExpiry, 5);
      expect(status.validUntil, '2026-06-29T00:00:00Z');
      expect(status.isExpiringSoon, isTrue);
    });

    test('parses active expiring license outside warning window', () {
      final status = LicenseStatus.fromJson({
        'status': 'active',
        'message': 'License active. 30 days remaining.',
        'licenseId': 'lic-123',
        'isLifetime': false,
        'daysUntilExpiry': 30,
        'validUntil': '2026-07-24T00:00:00Z',
      });

      expect(status.isLifetime, isFalse);
      expect(status.daysUntilExpiry, 30);
      expect(status.isExpiringSoon, isFalse);
    });

    test('parses invalid license', () {
      final status = LicenseStatus.fromJson({
        'status': 'invalid',
        'message': 'License has expired.',
      });

      expect(status.state, LicenseState.invalid);
      expect(status.isActive, isFalse);
      expect(status.isExpiringSoon, isFalse);
    });

    test('parses missing license', () {
      final status = LicenseStatus.fromJson({
        'status': 'missing',
        'message': 'USB license was not found.',
      });

      expect(status.state, LicenseState.missing);
      expect(status.isActive, isFalse);
    });

    test('unknown status defaults to missing', () {
      final status = LicenseStatus.fromJson({
        'status': 'unknown_state',
        'message': 'Something unexpected.',
      });

      expect(status.state, LicenseState.missing);
    });
  });
}

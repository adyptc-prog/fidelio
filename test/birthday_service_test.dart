import 'package:flutter_test/flutter_test.dart';
import 'package:fidelio/domain/entities/customer_record.dart';
import 'package:fidelio/domain/services/birthday_service.dart';
import 'package:fidelio/domain/value_objects/customer_status.dart';

void main() {
  group('customersWithBirthdayToday', () {
    final today = DateTime(2026, 5, 13);

    CustomerRecord customer({
      required String id,
      int? birthMonth,
      int? birthDay,
      int? lastBirthdayPromptYear,
    }) {
      return CustomerRecord(
        customerId: id,
        businessId: 'business-1',
        displayName: 'Customer $id',
        createdAt: today,
        updatedAt: today,
        status: CustomerStatus.active,
        birthMonth: birthMonth,
        birthDay: birthDay,
        lastBirthdayPromptYear: lastBirthdayPromptYear,
      );
    }

    test('includes a customer whose birthday matches today', () {
      final result = customersWithBirthdayToday([
        customer(id: 'a', birthMonth: 5, birthDay: 13),
      ], today: today);
      expect(result, hasLength(1));
      expect(result.single.customerId, 'a');
    });

    test('excludes customers without a birthday set', () {
      final result = customersWithBirthdayToday([
        customer(id: 'a'),
      ], today: today);
      expect(result, isEmpty);
    });

    test('excludes customers whose birthday is a different day', () {
      final result = customersWithBirthdayToday([
        customer(id: 'a', birthMonth: 5, birthDay: 14),
        customer(id: 'b', birthMonth: 6, birthDay: 13),
      ], today: today);
      expect(result, isEmpty);
    });

    test('excludes customers already prompted this year', () {
      final result = customersWithBirthdayToday([
        customer(
          id: 'a',
          birthMonth: 5,
          birthDay: 13,
          lastBirthdayPromptYear: 2026,
        ),
      ], today: today);
      expect(result, isEmpty);
    });

    test('includes a customer prompted in a previous year', () {
      final result = customersWithBirthdayToday([
        customer(
          id: 'a',
          birthMonth: 5,
          birthDay: 13,
          lastBirthdayPromptYear: 2025,
        ),
      ], today: today);
      expect(result, hasLength(1));
    });
  });

  group('nextBirthdayOccurrence', () {
    test('schedules later this year when the date has not passed yet', () {
      final from = DateTime(2026, 5, 1, 8);
      final next = nextBirthdayOccurrence(month: 5, day: 13, from: from);
      expect(next, DateTime(2026, 5, 13, 9));
    });

    test('schedules next year when the date already passed', () {
      final from = DateTime(2026, 6, 1, 8);
      final next = nextBirthdayOccurrence(month: 5, day: 13, from: from);
      expect(next, DateTime(2027, 5, 13, 9));
    });

    test('schedules next year when it is today but past the target hour', () {
      final from = DateTime(2026, 5, 13, 10);
      final next = nextBirthdayOccurrence(month: 5, day: 13, from: from);
      expect(next, DateTime(2027, 5, 13, 9));
    });
  });
}

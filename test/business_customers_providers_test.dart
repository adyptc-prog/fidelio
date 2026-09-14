import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fidelio/app/providers/app_settings_providers.dart';
import 'package:fidelio/app/providers/business_customers_providers.dart';
import 'package:fidelio/data/local_db/app_database.dart';
import 'package:fidelio/data/repositories/drift_repositories.dart';
import 'package:fidelio/data/services/birthday_notification_service.dart';
import 'package:fidelio/domain/entities/business_profile.dart';
import 'package:fidelio/domain/entities/customer_record.dart';

class _NoopBirthdayNotificationService implements BirthdayNotificationService {
  @override
  Future<void> scheduleBirthdayReminders(
    List<CustomerRecord> customers,
  ) async {}
}

void main() {
  group('BusinessCustomersController birthdays', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = AppDatabase.memory();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          birthdayNotificationServiceProvider.overrideWithValue(
            _NoopBirthdayNotificationService(),
          ),
        ],
      );
      await DriftBusinessRepository(db).saveBusinessProfile(
        BusinessProfile(
          businessId: 'business-1',
          displayName: 'Coffee Shop',
          createdAt: DateTime.now(),
        ),
      );
    });

    tearDown(() {
      container.dispose();
      db.close();
    });

    test('saveCustomer persists an optional birthday', () async {
      await container
          .read(businessCustomersControllerProvider.notifier)
          .saveCustomer(displayName: 'Ana Pop', birthMonth: 5, birthDay: 13);

      final customers = await DriftCustomerRepository(
        db,
      ).listCustomers('business-1');
      expect(customers.single.birthMonth, 5);
      expect(customers.single.birthDay, 13);
      expect(customers.single.hasBirthday, isTrue);
    });

    test('saveCustomer without a birthday leaves it unset', () async {
      await container
          .read(businessCustomersControllerProvider.notifier)
          .saveCustomer(displayName: 'Ana Pop');

      final customers = await DriftCustomerRepository(
        db,
      ).listCustomers('business-1');
      expect(customers.single.hasBirthday, isFalse);
    });

    test(
      'markBirthdayPrompted records the current year without touching other fields',
      () async {
        await container
            .read(businessCustomersControllerProvider.notifier)
            .saveCustomer(
              displayName: 'Ana Pop',
              phone: '0700000000',
              birthMonth: 5,
              birthDay: 13,
            );
        final created = (await DriftCustomerRepository(
          db,
        ).listCustomers('business-1')).single;

        await container
            .read(businessCustomersControllerProvider.notifier)
            .markBirthdayPrompted(created.customerId);

        final updated = await DriftCustomerRepository(
          db,
        ).getCustomer(created.customerId);
        expect(updated?.lastBirthdayPromptYear, DateTime.now().year);
        expect(updated?.phone, '0700000000');
        expect(updated?.birthMonth, 5);
        expect(updated?.birthDay, 13);
      },
    );
  });
}

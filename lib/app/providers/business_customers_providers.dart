import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/drift_repositories.dart';
import '../../data/repositories/repository_interfaces.dart';
import '../../data/services/birthday_notification_service.dart';
import '../../domain/entities/customer_record.dart';
import '../../domain/value_objects/customer_status.dart';
import 'app_settings_providers.dart';
import 'business_profile_providers.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return DriftCustomerRepository(ref.watch(appDatabaseProvider));
});

final birthdayNotificationServiceProvider =
    Provider<BirthdayNotificationService>((ref) {
      return BirthdayNotificationService();
    });

final businessCustomersControllerProvider =
    AsyncNotifierProvider<BusinessCustomersController, BusinessCustomersState>(
      BusinessCustomersController.new,
    );

class BusinessCustomersState {
  const BusinessCustomersState({required this.customers, this.query = ''});

  final List<CustomerRecord> customers;
  final String query;

  BusinessCustomersState copyWith({
    List<CustomerRecord>? customers,
    String? query,
  }) {
    return BusinessCustomersState(
      customers: customers ?? this.customers,
      query: query ?? this.query,
    );
  }
}

class BusinessCustomersController
    extends AsyncNotifier<BusinessCustomersState> {
  @override
  Future<BusinessCustomersState> build() async {
    final customers = await _loadCustomers('');
    unawaited(_rescheduleBirthdayReminders(customers));
    return BusinessCustomersState(customers: customers);
  }

  Future<void> setQuery(String query) async {
    final normalized = query.trim();
    state = await AsyncValue.guard(() async {
      final customers = await _loadCustomers(normalized);
      return BusinessCustomersState(customers: customers, query: normalized);
    });
  }

  Future<void> saveCustomer({
    String? customerId,
    required String displayName,
    String? phone,
    String? email,
    String? notes,
    int? birthMonth,
    int? birthDay,
  }) async {
    final normalizedName = displayName.trim();
    final normalizedPhone = phone?.trim() ?? '';
    if (normalizedName.isEmpty && normalizedPhone.isEmpty) {
      throw const CustomerValidationException(
        'Enter a customer name or phone number.',
      );
    }

    final businessId = await _businessId();
    final repository = ref.read(customerRepositoryProvider);
    final now = DateTime.now();
    final existing = customerId == null
        ? null
        : await repository.getCustomer(customerId);

    final customer = CustomerRecord(
      customerId: existing?.customerId ?? _newCustomerId(),
      businessId: businessId,
      displayName: normalizedName.isEmpty ? normalizedPhone : normalizedName,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      status: existing?.status ?? CustomerStatus.active,
      phone: _nullableText(normalizedPhone),
      email: _nullableText(email),
      notes: _nullableText(notes),
      linkedWalletId: existing?.linkedWalletId,
      birthMonth: birthMonth,
      birthDay: birthDay,
      lastBirthdayPromptYear: existing?.lastBirthdayPromptYear,
      rewardsEarned: existing?.rewardsEarned ?? 0,
      lastVisitAt: existing?.lastVisitAt,
    );

    await repository.saveCustomer(customer);
    await _refresh();
    unawaited(
      _rescheduleBirthdayReminders(state.valueOrNull?.customers ?? const []),
    );
  }

  /// Marks that the birthday reward prompt was shown (accepted or declined)
  /// for [customerId] this calendar year, so it is not shown again.
  Future<void> markBirthdayPrompted(String customerId) async {
    final repository = ref.read(customerRepositoryProvider);
    final existing = await repository.getCustomer(customerId);
    if (existing == null) {
      return;
    }
    await repository.saveCustomer(
      existing.copyWith(lastBirthdayPromptYear: DateTime.now().year),
    );
    await _refresh();
  }

  Future<void> archiveCustomer(String customerId) async {
    await ref.read(customerRepositoryProvider).archiveCustomer(customerId);
    await _refresh();
  }

  Future<void> deleteCustomer(String customerId) async {
    await ref.read(customerRepositoryProvider).deleteCustomer(customerId);
    await _refresh();
  }

  Future<void> _refresh() async {
    final query = state.valueOrNull?.query ?? '';
    state = await AsyncValue.guard(() async {
      final customers = await _loadCustomers(query);
      return BusinessCustomersState(customers: customers, query: query);
    });
  }

  Future<void> _rescheduleBirthdayReminders(
    List<CustomerRecord> customers,
  ) async {
    await ref
        .read(birthdayNotificationServiceProvider)
        .scheduleBirthdayReminders(customers);
  }

  Future<List<CustomerRecord>> _loadCustomers(String query) async {
    final businessId = await _businessId();
    final repository = ref.read(customerRepositoryProvider);
    if (query.isEmpty) {
      return repository.listCustomers(businessId);
    }
    return repository.searchCustomers(businessId, query);
  }

  Future<String> _businessId() async {
    final profile = await ref.read(businessProfileControllerProvider.future);
    if (profile == null) {
      throw StateError('Business profile must be configured first.');
    }
    return profile.businessId;
  }

  static String _newCustomerId() {
    return 'customer-${DateTime.now().microsecondsSinceEpoch}';
  }

  static String? _nullableText(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// Records that [customerId] just redeemed a loyalty reward (a card reaching
/// its threshold and the bonus being consumed), incrementing their reward
/// count and refreshing the customer list so their rank updates everywhere
/// it's displayed. Safe to call from any provider via its [Ref].
Future<void> recordCustomerRewardEarned(Ref ref, String customerId) async {
  final repository = ref.read(customerRepositoryProvider);
  final existing = await repository.getCustomer(customerId);
  if (existing == null) {
    return;
  }
  await repository.saveCustomer(
    existing.copyWith(rewardsEarned: existing.rewardsEarned + 1),
  );
  ref.invalidate(businessCustomersControllerProvider);
}

/// Records that [customerId] just visited (a validated QR/NFC check-in, or a
/// delivery stamp added), stamping their last-visit date. Safe to call from
/// any provider via its [Ref].
Future<void> recordCustomerVisit(Ref ref, String customerId) async {
  final repository = ref.read(customerRepositoryProvider);
  final existing = await repository.getCustomer(customerId);
  if (existing == null) {
    return;
  }
  await repository.saveCustomer(existing.copyWith(lastVisitAt: DateTime.now()));
  ref.invalidate(businessCustomersControllerProvider);
}

class CustomerValidationException implements Exception {
  const CustomerValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

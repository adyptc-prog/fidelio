import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/drift_repositories.dart';
import '../../data/repositories/repository_interfaces.dart';
import '../../domain/entities/customer_record.dart';
import '../../domain/value_objects/customer_status.dart';
import 'app_settings_providers.dart';
import 'business_profile_providers.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return DriftCustomerRepository(ref.watch(appDatabaseProvider));
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
    );

    await repository.saveCustomer(customer);
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

class CustomerValidationException implements Exception {
  const CustomerValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

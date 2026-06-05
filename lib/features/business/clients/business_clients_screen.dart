import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/app_settings_providers.dart';
import '../../../app/providers/business_customers_providers.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/customer_record.dart';
import '../../../domain/value_objects/customer_status.dart';
import '../../../presentation/layouts/section_shell.dart';
import 'customer_form_dialog.dart';

class BusinessClientsScreen extends ConsumerWidget {
  const BusinessClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersState = ref.watch(businessCustomersControllerProvider);
    final settings =
        ref.watch(appSettingsControllerProvider).valueOrNull ??
        const AppSettings(selectedMode: null);

    return SectionShell(
      title: 'Customers',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search by name, phone, or email',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    ref
                        .read(businessCustomersControllerProvider.notifier)
                        .setQuery(value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                tooltip: 'Add Customer',
                icon: const Icon(Icons.person_add),
                onPressed: () => showCustomerFormDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: customersState.when(
              data: (state) => _CustomersList(
                customers: state.customers,
                viewMode: settings.businessClientsViewMode,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Center(child: Text('Could not load customers: $error')),
            ),
          ),
        ],
      ),
    );
  }
}

String _customerSubtitle(CustomerRecord customer) {
  final parts = [
    if (customer.phone != null) customer.phone!,
    if (customer.email != null) customer.email!,
    customer.status == CustomerStatus.active ? 'active' : 'inactive',
  ];
  return parts.join(' - ');
}

class _CustomersList extends StatelessWidget {
  const _CustomersList({required this.customers, required this.viewMode});

  final List<CustomerRecord> customers;
  final BusinessClientsViewMode viewMode;

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return const Center(
        child: Text(
          'No customers match the current search.',
          textAlign: TextAlign.center,
        ),
      );
    }

    if (viewMode == BusinessClientsViewMode.grid) {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1,
        ),
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final customer = customers[index];
          return _CustomerGridCard(customer: customer);
        },
      );
    }

    return ListView.separated(
      itemCount: customers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final customer = customers[index];
        return Card(
          child: ListTile(
            leading: Icon(
              customer.status == CustomerStatus.active
                  ? Icons.person
                  : Icons.person_off,
            ),
            title: Text(customer.displayName),
            subtitle: Text(_customerSubtitle(customer)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                context.push('/business/clients/${customer.customerId}'),
          ),
        );
      },
    );
  }
}

class _CustomerGridCard extends StatelessWidget {
  const _CustomerGridCard({required this.customer});

  final CustomerRecord customer;

  @override
  Widget build(BuildContext context) {
    final isActive = customer.status == CustomerStatus.active;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/business/clients/${customer.customerId}'),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isActive
                  ? const [Color(0xFF0B3B34), Color(0xFF16705F)]
                  : const [Color(0xFF58616B), Color(0xFF171C22)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26061412),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isActive ? Icons.person : Icons.person_off,
                  color: Colors.white,
                  size: 30,
                ),
                const Spacer(),
                Text(
                  customer.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _subtitle(customer),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(CustomerRecord customer) {
    final parts = [
      if (customer.phone != null) customer.phone!,
      if (customer.email != null) customer.email!,
      customer.status == CustomerStatus.active ? 'active' : 'inactive',
    ];
    return parts.join(' · ');
  }
}

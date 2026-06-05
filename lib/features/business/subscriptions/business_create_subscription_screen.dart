import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/business_customers_providers.dart';
import '../../../app/providers/business_subscriptions_providers.dart';
import '../../../domain/entities/customer_record.dart';
import '../../../domain/value_objects/customer_status.dart';
import '../../../domain/value_objects/subscription_type.dart';
import '../../../presentation/layouts/section_shell.dart';
import '../clients/license_required_dialog.dart';

class BusinessCreateSubscriptionScreen extends ConsumerStatefulWidget {
  const BusinessCreateSubscriptionScreen({super.key});

  @override
  ConsumerState<BusinessCreateSubscriptionScreen> createState() =>
      _BusinessCreateSubscriptionScreenState();
}

class _BusinessCreateSubscriptionScreenState
    extends ConsumerState<BusinessCreateSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Membership 10 entries');
  final _usesController = TextEditingController(text: '10');
  String? _selectedCustomerId;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(businessCustomersControllerProvider);

    return SectionShell(
      title: 'Create Membership',
      child: customersState.when(
        data: (state) => _buildForm(
          state.customers
              .where((customer) => customer.status == CustomerStatus.active)
              .toList(),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Could not load customers: $error')),
      ),
    );
  }

  Widget _buildForm(List<CustomerRecord> customers) {
    _selectedCustomerId ??= customers.isEmpty
        ? null
        : customers.first.customerId;
    if (_selectedCustomerId != null &&
        !customers.any(
          (customer) => customer.customerId == _selectedCustomerId,
        )) {
      _selectedCustomerId = customers.isEmpty
          ? null
          : customers.first.customerId;
    }

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Issue Local Membership',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (customers.isEmpty)
                    const Text('Add an active customer first.')
                  else ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCustomerId,
                      decoration: const InputDecoration(
                        labelText: 'Client',
                        border: OutlineInputBorder(),
                      ),
                      items: customers
                          .map(
                            (customer) => DropdownMenuItem(
                              value: customer.customerId,
                              child: Text(customer.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: _isSaving
                          ? null
                          : (value) => setState(() {
                              _selectedCustomerId = value;
                            }),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Membership Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _usesController,
                      decoration: const InputDecoration(
                        labelText: 'Entry Count',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: _positiveNomber,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.card_membership),
                      label: Text(_isSaving ? 'Saving...' : 'Save Membership'),
                      onPressed: _isSaving ? null : _saveSubscription,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required field.';
    }
    return null;
  }

  String? _positiveNomber(String? value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed <= 0) {
      return 'Enter a positive number.';
    }
    return null;
  }

  Future<void> _saveSubscription() async {
    if (!_formKey.currentState!.validate() || _selectedCustomerId == null) {
      return;
    }

    final selectedCustomer = ref
        .read(businessCustomersControllerProvider)
        .valueOrNull
        ?.customers
        .where((customer) => customer.customerId == _selectedCustomerId)
        .firstOrNull;
    if (selectedCustomer == null) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      await ref
          .read(businessSubscriptionActionsProvider)
          .createSubscription(
            businessId: selectedCustomer.businessId,
            customerId: selectedCustomer.customerId,
            type: SubscriptionType.entries,
            name: _nameController.text,
            startsAt: now,
            expiresAt: now.add(const Duration(days: 30)),
            remainingUses: int.parse(_usesController.text),
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Membership was saved.')));
    } on LicenseRequiredException {
      if (mounted) {
        await showLicenseRequiredDialog(context);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save membership: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/business_customers_providers.dart';
import '../../../app/providers/business_subscriptions_providers.dart';
import '../../../domain/entities/customer_record.dart';
import '../../../domain/value_objects/customer_status.dart';
import '../../../domain/value_objects/loyalty_program_type.dart';
import '../../../presentation/layouts/section_shell.dart';
import '../clients/license_required_dialog.dart';

class BusinessCreateLoyaltyScreen extends ConsumerStatefulWidget {
  const BusinessCreateLoyaltyScreen({super.key});

  @override
  ConsumerState<BusinessCreateLoyaltyScreen> createState() =>
      _BusinessCreateLoyaltyScreenState();
}

class _BusinessCreateLoyaltyScreenState
    extends ConsumerState<BusinessCreateLoyaltyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Coffee Loyalty');
  final _thresholdController = TextEditingController(text: '8');
  final _pointsPerScanController = TextEditingController(text: '10');
  final _windowDaysController = TextEditingController(text: '30');
  String? _selectedCustomerId;
  LoyaltyProgramType _programType = LoyaltyProgramType.stamps;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _thresholdController.dispose();
    _pointsPerScanController.dispose();
    _windowDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(businessCustomersControllerProvider);

    return SectionShell(
      title: 'Create Loyalty Card',
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
                    'Issue Local Card',
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
                    if (_programType == LoyaltyProgramType.points) ...[
                      TextFormField(
                        controller: _pointsPerScanController,
                        decoration: const InputDecoration(
                          labelText: 'Points awarded per scan',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: _positiveNomber,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_programType == LoyaltyProgramType.visitChallenge) ...[
                      TextFormField(
                        controller: _windowDaysController,
                        decoration: const InputDecoration(
                          labelText: 'Challenge period in days',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: _positiveNomber,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Card Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<LoyaltyProgramType>(
                      initialValue: _programType,
                      decoration: const InputDecoration(
                        labelText: 'Loyalty Program Type',
                        border: OutlineInputBorder(),
                      ),
                      items: LoyaltyProgramType.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(_programTypeLabel(type)),
                            ),
                          )
                          .toList(),
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _programType = value;
                                _thresholdController.text = _defaultThreshold(
                                  value,
                                );
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _thresholdController,
                      decoration: InputDecoration(
                        labelText: _thresholdLabel(_programType),
                        helperText:
                            'After this many entries, the next one will be '
                            'the bonus entry. Once the bonus is redeemed, '
                            'the card is fully used and a new one must be '
                            'created.',
                        helperMaxLines: 3,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: _positiveNomber,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.loyalty),
                      label: Text(_isSaving ? 'Saving...' : 'Save Card'),
                      onPressed: _isSaving ? null : _saveLoyaltyCard,
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

  Future<void> _saveLoyaltyCard() async {
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
      await ref
          .read(businessSubscriptionActionsProvider)
          .createLoyaltyCard(
            businessId: selectedCustomer.businessId,
            customerId: selectedCustomer.customerId,
            name: _nameController.text,
            rewardThreshold: int.parse(_thresholdController.text),
            programType: _programType,
            pointsPerScan: _programType == LoyaltyProgramType.points
                ? int.parse(_pointsPerScanController.text)
                : null,
            challengeWindowDays:
                _programType == LoyaltyProgramType.visitChallenge
                ? int.parse(_windowDaysController.text)
                : null,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Loyalty card was saved.')));
    } on LicenseRequiredException {
      if (mounted) {
        await showLicenseRequiredDialog(context);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save loyalty card: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

String _programTypeLabel(LoyaltyProgramType type) {
  return switch (type) {
    LoyaltyProgramType.stamps => 'Stamps',
    LoyaltyProgramType.points => 'Points per Visit',
    LoyaltyProgramType.visitChallenge => 'Visit Challenge',
    LoyaltyProgramType.delivery => 'Delivery',
  };
}

String _thresholdLabel(LoyaltyProgramType type) {
  return switch (type) {
    LoyaltyProgramType.stamps => 'Number of stamps before bonus entry',
    LoyaltyProgramType.points => 'Number of points before bonus entry',
    LoyaltyProgramType.visitChallenge => 'Number of visits before bonus entry',
    LoyaltyProgramType.delivery => 'Number of deliveries before bonus entry',
  };
}

String _defaultThreshold(LoyaltyProgramType type) {
  return switch (type) {
    LoyaltyProgramType.stamps => '8',
    LoyaltyProgramType.points => '100',
    LoyaltyProgramType.visitChallenge => '10',
    LoyaltyProgramType.delivery => '5',
  };
}

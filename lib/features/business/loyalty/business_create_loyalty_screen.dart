import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/business_customers_providers.dart';
import '../../../app/providers/business_subscriptions_providers.dart';
import '../../../domain/entities/customer_record.dart';
import '../../../domain/value_objects/customer_status.dart';
import '../../../domain/value_objects/loyalty_program_type.dart';
import '../../../presentation/layouts/section_shell.dart';
import '../clients/license_required_dialog.dart';
import 'package:fidelio/app/localization/app_language.dart';

class BusinessCreateLoyaltyScreen extends ConsumerStatefulWidget {
  const BusinessCreateLoyaltyScreen({super.key});

  @override
  ConsumerState<BusinessCreateLoyaltyScreen> createState() =>
      _BusinessCreateLoyaltyScreenState();
}

class _BusinessCreateLoyaltyScreenState
    extends ConsumerState<BusinessCreateLoyaltyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: t('Coffee Loyalty'));
  final _thresholdController = TextEditingController(text: '8');
  final _pointsPerScanController = TextEditingController(text: '10');
  final _windowDaysController = TextEditingController(text: '30');
  final _startsAtController = TextEditingController();
  final _validUntilController = TextEditingController();
  String? _selectedCustomerId;
  LoyaltyProgramType _programType = LoyaltyProgramType.stamps;
  DateTime _startsAt = DateTime.now();
  DateTime? _validUntil;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _syncDateControllers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _thresholdController.dispose();
    _pointsPerScanController.dispose();
    _windowDaysController.dispose();
    _startsAtController.dispose();
    _validUntilController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(businessCustomersControllerProvider);

    return SectionShell(
      title: t('Create Loyalty Card'),
      child: customersState.when(
        data: (state) => _buildForm(
          state.customers
              .where((customer) => customer.status == CustomerStatus.active)
              .toList(),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text(tr('Clienții nu au putut fi încărcați: $error', 'Could not load customers: $error'))),
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
                    t('Issue Local Card'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (customers.isEmpty)
                    Text(t('Add an active customer first.'))
                  else ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCustomerId,
                      decoration: InputDecoration(
                        labelText: t('Client'),
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
                        decoration: InputDecoration(
                          labelText: t('Points awarded per scan'),
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
                        decoration: InputDecoration(
                          labelText: t('Challenge period in days'),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: _positiveNomber,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: t('Card Name'),
                        border: OutlineInputBorder(),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<LoyaltyProgramType>(
                      initialValue: _programType,
                      decoration: InputDecoration(
                        labelText: t('Loyalty Program Type'),
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
                        helperText: tr(
                            'După atâtea intrări, următoarea e intrarea bonus. '
                            'După ce bonusul e acordat, cardul e folosit complet '
                            'și trebuie creat unul nou.',
                            'After this many entries, the next one will be '
                            'the bonus entry. Once the bonus is redeemed, '
                            'the card is fully used and a new one must be '
                            'created.'),
                        helperMaxLines: 3,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: _positiveNomber,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _startsAtController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: t('Valid From'),
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: _isSaving ? null : () => _pickDate(isStart: true),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _validUntilController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: t('Valid Until (optional)'),
                        border: const OutlineInputBorder(),
                        suffixIcon: _validUntil == null
                            ? const Icon(Icons.calendar_today)
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _isSaving
                                    ? null
                                    : () => setState(() {
                                        _validUntil = null;
                                        _syncDateControllers();
                                      }),
                              ),
                      ),
                      onTap: _isSaving ? null : () => _pickDate(isStart: false),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.loyalty),
                      label: Text(_isSaving ? t('Saving...') : t('Save Card')),
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

  Future<void> _pickDate({required bool isStart}) async {
    // Sfârșitul nu poate fi înaintea începutului: calendarul pentru
    // sfârșit începe de la data de început.
    final startDay = DateUtils.dateOnly(_startsAt);
    var initialDate = isStart ? _startsAt : (_validUntil ?? _startsAt);
    if (!isStart && initialDate.isBefore(startDay)) {
      initialDate = startDay;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: isStart ? DateTime(2020) : startDay,
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isStart) {
        _startsAt = picked;
        if (_validUntil != null && _validUntil!.isBefore(_startsAt)) {
          _validUntil = _startsAt;
        }
      } else {
        _validUntil = picked;
      }
      _syncDateControllers();
    });
  }

  void _syncDateControllers() {
    _startsAtController.text = _formatDate(_startsAt);
    _validUntilController.text = _validUntil == null
        ? t('No expiration')
        : _formatDate(_validUntil!);
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return t('Required field.');
    }
    return null;
  }

  String? _positiveNomber(String? value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed <= 0) {
      return t('Enter a positive number.');
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
            startsAt: _startsAt,
            validUntil: _validUntil,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('Loyalty card was saved.'))));
    } on LicenseRequiredException {
      if (mounted) {
        await showLicenseRequiredDialog(context);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Cardul de fidelitate nu a putut fi salvat: $error', 'Could not save loyalty card: $error'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _programTypeLabel(LoyaltyProgramType type) {
  return switch (type) {
    LoyaltyProgramType.stamps => t('Stamps'),
    LoyaltyProgramType.points => t('Points per Visit'),
    LoyaltyProgramType.visitChallenge => t('Visit Challenge'),
    LoyaltyProgramType.delivery => t('Delivery'),
  };
}

String _thresholdLabel(LoyaltyProgramType type) {
  return switch (type) {
    LoyaltyProgramType.stamps => t('Number of stamps before bonus entry'),
    LoyaltyProgramType.points => t('Number of points before bonus entry'),
    LoyaltyProgramType.visitChallenge => t('Number of visits before bonus entry'),
    LoyaltyProgramType.delivery => t('Number of deliveries before bonus entry'),
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

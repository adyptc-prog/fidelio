import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/business_subscriptions_providers.dart';
import '../../../domain/entities/customer_record.dart';
import '../../../domain/value_objects/loyalty_program_type.dart';
import 'license_required_dialog.dart';

Future<void> showLoyaltyFormDialog(
  BuildContext context, {
  required CustomerRecord customer,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _LoyaltyFormDialog(customer: customer),
  );
}

class _LoyaltyFormDialog extends ConsumerStatefulWidget {
  const _LoyaltyFormDialog({required this.customer});

  final CustomerRecord customer;

  @override
  ConsumerState<_LoyaltyFormDialog> createState() => _LoyaltyFormDialogState();
}

class _LoyaltyFormDialogState extends ConsumerState<_LoyaltyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Loyalty Card');
  final _thresholdController = TextEditingController(text: '8');
  final _pointsPerScanController = TextEditingController(text: '10');
  final _windowDaysController = TextEditingController(text: '30');
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
    return AlertDialog(
      title: const Text('Create Loyalty Card'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _programType = value;
                    _thresholdController.text = _defaultThreshold(value);
                  });
                },
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
                controller: _thresholdController,
                decoration: const InputDecoration(
                  labelText: 'Reward Threshold',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: _positiveNomber,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final warning = await ref
          .read(businessSubscriptionActionsProvider)
          .createLoyaltyCard(
            businessId: widget.customer.businessId,
            customerId: widget.customer.customerId,
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
      if (warning != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(warning),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 6),
          ),
        );
      }
      Navigator.of(context).pop();
    } on LicenseRequiredException {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      await showLicenseRequiredDialog(context);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save loyalty card: $error')),
      );
    }
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
}

String _programTypeLabel(LoyaltyProgramType type) {
  return switch (type) {
    LoyaltyProgramType.stamps => 'Stamps',
    LoyaltyProgramType.points => 'Points per Visit',
    LoyaltyProgramType.visitChallenge => 'Visit Challenge',
    LoyaltyProgramType.delivery => 'Delivery',
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

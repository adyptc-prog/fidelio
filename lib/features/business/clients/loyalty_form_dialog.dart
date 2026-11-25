import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/business_subscriptions_providers.dart';
import '../../../domain/entities/customer_record.dart';
import '../../../domain/value_objects/loyalty_program_type.dart';
import 'license_required_dialog.dart';
import 'package:fidelio/app/localization/app_language.dart';

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
  final _nameController = TextEditingController(text: t('Loyalty Card'));
  final _thresholdController = TextEditingController(text: '8');
  final _pointsPerScanController = TextEditingController(text: '10');
  final _windowDaysController = TextEditingController(text: '30');
  final _startsAtController = TextEditingController();
  final _validUntilController = TextEditingController();
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
    return AlertDialog(
      title: Text(t('Create Loyalty Card')),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  controller: _thresholdController,
                  decoration: InputDecoration(
                    labelText: t('Reward Threshold'),
                    border: OutlineInputBorder(),
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
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('Cancel')),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? t('Saving...') : t('Save')),
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
            startsAt: _startsAt,
            validUntil: _validUntil,
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
        SnackBar(content: Text(tr('Cardul de fidelitate nu a putut fi salvat: $error', 'Could not save loyalty card: $error'))),
      );
    }
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

String _defaultThreshold(LoyaltyProgramType type) {
  return switch (type) {
    LoyaltyProgramType.stamps => '8',
    LoyaltyProgramType.points => '100',
    LoyaltyProgramType.visitChallenge => '10',
    LoyaltyProgramType.delivery => '5',
  };
}

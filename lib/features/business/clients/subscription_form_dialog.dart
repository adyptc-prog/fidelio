import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/business_subscriptions_providers.dart';
import '../../../domain/entities/customer_record.dart';
import '../../../domain/value_objects/subscription_type.dart';
import 'license_required_dialog.dart';

Future<void> showSubscriptionFormDialog(
  BuildContext context, {
  required CustomerRecord customer,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _SubscriptionFormDialog(customer: customer),
  );
}

class _SubscriptionFormDialog extends ConsumerStatefulWidget {
  const _SubscriptionFormDialog({required this.customer});

  final CustomerRecord customer;

  @override
  ConsumerState<_SubscriptionFormDialog> createState() =>
      _SubscriptionFormDialogState();
}

class _SubscriptionFormDialogState
    extends ConsumerState<_SubscriptionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Membership monthly');
  final _startsAtController = TextEditingController();
  final _expiresAtController = TextEditingController();
  final _entriesController = TextEditingController();
  final _notesController = TextEditingController();
  SubscriptionType _type = SubscriptionType.monthly;
  DateTime _startsAt = DateTime.now();
  late DateTime _expiresAt;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _expiresAt = DateTime(_startsAt.year, _startsAt.month + 1, _startsAt.day);
    _syncDateControllers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startsAtController.dispose();
    _expiresAtController.dispose();
    _entriesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Membership'),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<SubscriptionType>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Membership Type',
                    border: OutlineInputBorder(),
                  ),
                  items: SubscriptionType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(_typeLabel(type)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _type = value);
                  },
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
                  controller: _startsAtController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Start Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () => _pickDate(isStart: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _expiresAtController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Expiration Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () => _pickDate(isStart: false),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _entriesController,
                  decoration: const InputDecoration(
                    labelText: 'Entry count optional',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: _optionalPositiveNomber,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes optional',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
              ],
            ),
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

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart ? _startsAt : _expiresAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isStart) {
        _startsAt = picked;
        if (_expiresAt.isBefore(_startsAt)) {
          _expiresAt = _startsAt;
        }
      } else {
        _expiresAt = picked;
      }
      _syncDateControllers();
    });
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
      await ref
          .read(businessSubscriptionActionsProvider)
          .createSubscription(
            businessId: widget.customer.businessId,
            customerId: widget.customer.customerId,
            type: _type,
            name: _nameController.text,
            startsAt: _startsAt,
            expiresAt: _expiresAt,
            remainingUses: _parseOptionalInt(_entriesController.text),
            notes: _notesController.text,
          );

      if (!mounted) {
        return;
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
        SnackBar(content: Text('Could not save membership: $error')),
      );
    }
  }

  void _syncDateControllers() {
    _startsAtController.text = _formatDate(_startsAt);
    _expiresAtController.text = _formatDate(_expiresAt);
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required field.';
    }
    return null;
  }

  String? _optionalPositiveNomber(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed <= 0) {
      return 'Enter a positive number.';
    }
    return null;
  }

  int? _parseOptionalInt(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : int.parse(trimmed);
  }
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _typeLabel(SubscriptionType type) {
  return switch (type) {
    SubscriptionType.monthly => 'Monthly',
    SubscriptionType.entries => 'Entry count',
    SubscriptionType.custom => 'Custom',
  };
}

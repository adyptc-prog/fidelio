import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/business_subscriptions_providers.dart';
import '../../../domain/entities/customer_record.dart';
import '../../../domain/value_objects/subscription_type.dart';
import 'license_required_dialog.dart';
import 'package:fidelio/app/localization/app_language.dart';

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
  final _nameController = TextEditingController(text: t('Membership monthly'));
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
      title: Text(t('Create Membership')),
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
                  decoration: InputDecoration(
                    labelText: t('Membership Type'),
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
                  decoration: InputDecoration(
                    labelText: t('Membership Name'),
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _startsAtController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: t('Start Date'),
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () => _pickDate(isStart: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _expiresAtController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: t('Expiration Date'),
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () => _pickDate(isStart: false),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _entriesController,
                  decoration: InputDecoration(
                    labelText: t('Entry count optional'),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: _optionalPositiveNomber,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: t('Notes optional'),
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
          child: Text(t('Cancel')),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? t('Saving...') : t('Save')),
        ),
      ],
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    // Sfârșitul nu poate fi înaintea începutului: calendarul pentru
    // sfârșit începe de la data de început.
    final startDay = DateUtils.dateOnly(_startsAt);
    var initialDate = isStart ? _startsAt : _expiresAt;
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
      final warning = await ref
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
        SnackBar(content: Text(tr('Abonamentul nu a putut fi salvat: $error', 'Could not save membership: $error'))),
      );
    }
  }

  void _syncDateControllers() {
    _startsAtController.text = _formatDate(_startsAt);
    _expiresAtController.text = _formatDate(_expiresAt);
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return t('Required field.');
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
      return t('Enter a positive number.');
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
    SubscriptionType.monthly => t('Monthly'),
    SubscriptionType.entries => t('Entry count'),
    SubscriptionType.custom => t('Custom'),
  };
}

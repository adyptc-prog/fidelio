import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/business_customers_providers.dart';
import '../../../domain/entities/customer_record.dart';
import 'package:fidelio/app/localization/app_language.dart';

Future<void> showCustomerFormDialog(
  BuildContext context, {
  CustomerRecord? customer,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CustomerFormDialog(customer: customer),
  );
}

class _CustomerFormDialog extends ConsumerStatefulWidget {
  const _CustomerFormDialog({this.customer});

  final CustomerRecord? customer;

  @override
  ConsumerState<_CustomerFormDialog> createState() =>
      _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<_CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  int? _birthMonth;
  int? _birthDay;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    if (customer == null) {
      return;
    }
    _nameController.text = customer.displayName;
    _phoneController.text = customer.phone ?? '';
    _emailController.text = customer.email ?? '';
    _notesController.text = customer.notes ?? '';
    _birthMonth = customer.birthMonth;
    _birthDay = customer.birthDay;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.customer == null ? t('Add Customer') : t('Edit Customer')),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: t('Customer Name optional'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: t('Phone optional'),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (_) => _nameOrPhone(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: t('Email optional'),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _optionalEmail,
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
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickBirthday,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: t('Birthday optional'),
                      border: const OutlineInputBorder(),
                      suffixIcon: _birthMonth == null
                          ? const Icon(Icons.cake_outlined)
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() {
                                _birthMonth = null;
                                _birthDay = null;
                              }),
                            ),
                    ),
                    child: Text(_birthdayLabel()),
                  ),
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
        FilledButton(onPressed: _save, child: Text(t('Save'))),
      ],
    );
  }

  Future<void> _pickBirthday() async {
    // A leap year so Feb 29 remains selectable; only month/day are kept.
    const neutralYear = 2000;
    final initialDate = _birthMonth == null
        ? DateTime(neutralYear)
        : DateTime(neutralYear, _birthMonth!, _birthDay!);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(neutralYear),
      lastDate: DateTime(neutralYear, 12, 31),
      initialDatePickerMode: DatePickerMode.day,
      helpText: t('Select birthday (year is ignored)'),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _birthMonth = picked.month;
      _birthDay = picked.day;
    });
  }

  String _birthdayLabel() {
    if (_birthMonth == null || _birthDay == null) {
      return t('Not set');
    }
    final months = [
      t('January'),
      t('February'),
      t('March'),
      t('April'),
      t('May'),
      t('June'),
      t('July'),
      t('August'),
      t('September'),
      t('October'),
      t('November'),
      t('December'),
    ];
    return '${months[_birthMonth! - 1]} $_birthDay';
  }

  String? _nameOrPhone() {
    if (_nameController.text.trim().isEmpty &&
        _phoneController.text.trim().isEmpty) {
      return t('Enter a customer name or phone number.');
    }
    return null;
  }

  String? _optionalEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty || trimmed.contains('@')) {
      return null;
    }
    return t('Enter a valid email or leave the field empty.');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await ref
          .read(businessCustomersControllerProvider.notifier)
          .saveCustomer(
            customerId: widget.customer?.customerId,
            displayName: _nameController.text,
            phone: _phoneController.text,
            email: _emailController.text,
            notes: _notesController.text,
            birthMonth: _birthMonth,
            birthDay: _birthDay,
          );
    } on CustomerValidationException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

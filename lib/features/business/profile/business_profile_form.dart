import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/business_profile_providers.dart';
import '../../../core/constants/route_names.dart';
import '../../../domain/entities/business_profile.dart';

class BusinessProfileForm extends ConsumerStatefulWidget {
  const BusinessProfileForm({
    required this.submitLabel,
    this.initialProfile,
    this.navigateToDashboardOnSave = false,
    super.key,
  });

  final BusinessProfile? initialProfile;
  final String submitLabel;
  final bool navigateToDashboardOnSave;

  @override
  ConsumerState<BusinessProfileForm> createState() =>
      _BusinessProfileFormState();
}

class _BusinessProfileFormState extends ConsumerState<BusinessProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _domainController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  int? _selectedAccentColor;
  String? _selectedActivitySymbol;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    if (profile == null) {
      return;
    }

    _nameController.text = profile.displayName;
    _domainController.text = profile.activityDomain ?? '';
    _phoneController.text = profile.phone ?? '';
    _emailController.text = profile.email ?? '';
    _addressController.text = profile.address ?? '';
    _selectedAccentColor = _knownAccentColor(profile.cardAccentColor);
    _selectedActivitySymbol = _knownActivitySymbol(profile.activitySymbol);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _domainController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saveState = ref.watch(businessProfileControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Business Name',
                  border: OutlineInputBorder(),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _domainController,
                decoration: const InputDecoration(
                  labelText: 'Business Activity',
                  border: OutlineInputBorder(),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _selectedActivitySymbol,
                decoration: const InputDecoration(
                  labelText: 'Activity Symbol',
                  border: OutlineInputBorder(),
                ),
                items: _activitySymbols
                    .map(
                      (symbol) => DropdownMenuItem<String?>(
                        value: symbol.value,
                        child: Row(
                          children: [
                            Icon(symbol.icon),
                            const SizedBox(width: 10),
                            Text(symbol.label),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedActivitySymbol = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone optional',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email optional',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: _optionalEmail,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address optional',
                  border: OutlineInputBorder(),
                ),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _selectedAccentColor,
                decoration: const InputDecoration(
                  labelText: 'Card Color',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Default')),
                  DropdownMenuItem(value: 0xFF2563EB, child: Text('Blue')),
                  DropdownMenuItem(value: 0xFFDC2626, child: Text('Red')),
                  DropdownMenuItem(value: 0xFF16A34A, child: Text('Green')),
                  DropdownMenuItem(value: 0xFFD6AA2F, child: Text('Gold')),
                  DropdownMenuItem(value: 0xFF7C3AED, child: Text('Purple')),
                  DropdownMenuItem(value: 0xFFEA580C, child: Text('Orange')),
                  DropdownMenuItem(value: 0xFF0F172A, child: Text('Black')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedAccentColor = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.save),
                label: Text(widget.submitLabel),
                onPressed: saveState.isLoading ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required field.';
    }
    return null;
  }

  String? _optionalEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty || trimmed.contains('@')) {
      return null;
    }
    return 'Enter a valid email or leave the field empty.';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final existing = widget.initialProfile;
    final profile = BusinessProfile(
      businessId: existing?.businessId ?? _newBusinessId(),
      displayName: _nameController.text.trim(),
      createdAt: existing?.createdAt ?? DateTime.now(),
      activityDomain: _nullableText(_domainController.text),
      phone: _nullableText(_phoneController.text),
      email: _nullableText(_emailController.text),
      address: _nullableText(_addressController.text),
      cardAccentColor: _selectedAccentColor,
      activitySymbol: _selectedActivitySymbol,
      localPublicKey: existing?.localPublicKey,
    );

    await ref
        .read(businessProfileControllerProvider.notifier)
        .saveProfile(profile);

    if (!mounted || !widget.navigateToDashboardOnSave) {
      return;
    }

    context.go(RouteNames.businessDashboard);
  }

  static String _newBusinessId() {
    return 'business-${DateTime.now().microsecondsSinceEpoch}';
  }

  static String? _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _knownAccentColor(int? value) {
    if (value == null) {
      return null;
    }
    return _accentColors.contains(value) ? value : null;
  }

  static String? _knownActivitySymbol(String? value) {
    if (value == null) {
      return null;
    }
    return _activitySymbols.any((symbol) => symbol.value == value)
        ? value
        : null;
  }
}

class _ActivitySymbolOption {
  const _ActivitySymbolOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String? value;
  final String label;
  final IconData icon;
}

const _activitySymbols = [
  _ActivitySymbolOption(value: null, label: 'Default', icon: Icons.storefront),
  _ActivitySymbolOption(
    value: 'robotics',
    label: 'Robotics',
    icon: Icons.precision_manufacturing,
  ),
  _ActivitySymbolOption(value: 'dance', label: 'Dance', icon: Icons.music_note),
  _ActivitySymbolOption(value: 'swimming', label: 'Swimming', icon: Icons.pool),
  _ActivitySymbolOption(
    value: 'fitness',
    label: 'Fitness',
    icon: Icons.fitness_center,
  ),
  _ActivitySymbolOption(value: 'beauty', label: 'Beauty', icon: Icons.spa),
  _ActivitySymbolOption(
    value: 'coffee',
    label: 'Coffee',
    icon: Icons.local_cafe,
  ),
  _ActivitySymbolOption(
    value: 'restaurant',
    label: 'Restaurant',
    icon: Icons.restaurant,
  ),
  _ActivitySymbolOption(
    value: 'education',
    label: 'Education',
    icon: Icons.school,
  ),
  _ActivitySymbolOption(
    value: 'medical',
    label: 'Medical',
    icon: Icons.medical_services,
  ),
  _ActivitySymbolOption(
    value: 'auto',
    label: 'Auto',
    icon: Icons.directions_car,
  ),
  _ActivitySymbolOption(
    value: 'retail',
    label: 'Retail',
    icon: Icons.shopping_bag,
  ),
];

const _accentColors = <int>{
  0xFF2563EB,
  0xFFDC2626,
  0xFF16A34A,
  0xFFD6AA2F,
  0xFF7C3AED,
  0xFFEA580C,
  0xFF0F172A,
};

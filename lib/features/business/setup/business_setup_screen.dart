import 'package:flutter/material.dart';

import '../../../presentation/layouts/section_shell.dart';
import '../profile/business_profile_form.dart';

class BusinessSetupScreen extends StatelessWidget {
  const BusinessSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SectionShell(
      title: 'Set Up Business',
      showBackButton: false,
      child: SingleChildScrollView(
        child: BusinessProfileForm(
          submitLabel: 'Save Profile',
          navigateToDashboardOnSave: true,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../presentation/layouts/section_shell.dart';
import '../profile/business_profile_form.dart';
import 'package:fidelio/app/localization/app_language.dart';

class BusinessSetupScreen extends StatelessWidget {
  const BusinessSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionShell(
      title: t('Set Up Business'),
      showBackButton: false,
      child: SingleChildScrollView(
        child: BusinessProfileForm(
          submitLabel: t('Save Profile'),
          navigateToDashboardOnSave: true,
        ),
      ),
    );
  }
}

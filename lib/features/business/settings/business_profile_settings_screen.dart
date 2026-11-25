import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/business_profile_providers.dart';
import '../../../presentation/layouts/section_shell.dart';
import '../profile/business_profile_form.dart';
import 'package:fidelio/app/localization/app_language.dart';

class BusinessProfileSettingsScreen extends ConsumerWidget {
  const BusinessProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(businessProfileControllerProvider);

    return SectionShell(
      title: t('Business Details'),
      child: ListView(
        children: [
          profile.when(
            data: (profile) => BusinessProfileForm(
              initialProfile: profile,
              submitLabel: t('Save Changes'),
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stackTrace) =>
                Text(tr('Profilul afacerii nu a putut fi încărcat: $error', 'Could not load business profile: $error')),
          ),
        ],
      ),
    );
  }
}

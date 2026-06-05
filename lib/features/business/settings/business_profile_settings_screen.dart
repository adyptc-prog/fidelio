import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/business_profile_providers.dart';
import '../../../presentation/layouts/section_shell.dart';
import '../profile/business_profile_form.dart';

class BusinessProfileSettingsScreen extends ConsumerWidget {
  const BusinessProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(businessProfileControllerProvider);

    return SectionShell(
      title: 'Business Details',
      child: ListView(
        children: [
          profile.when(
            data: (profile) => BusinessProfileForm(
              initialProfile: profile,
              submitLabel: 'Save Changes',
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stackTrace) =>
                Text('Could not load business profile: $error'),
          ),
        ],
      ),
    );
  }
}

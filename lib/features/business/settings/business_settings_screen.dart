import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/app_settings_providers.dart';
import '../../../app/providers/business_profile_providers.dart';
import '../../../core/constants/route_names.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/value_objects/app_mode.dart';
import '../../../presentation/layouts/section_shell.dart';
import '../../../presentation/widgets/change_app_mode_tile.dart';
import 'package:fidelio/app/localization/app_language.dart';
import 'package:fidelio/presentation/widgets/language_tile.dart';

class BusinessSettingsScreen extends ConsumerWidget {
  const BusinessSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final current =
        settings.valueOrNull ?? const AppSettings(selectedMode: null);
    final controller = ref.read(appSettingsControllerProvider.notifier);
    final business = ref.watch(businessProfileControllerProvider);

    return SectionShell(
      title: t('Business Settings'),
      child: ListView(
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront),
              title: Text(t('Business Details')),
              subtitle: Text(t('Profile, contact, address and card color')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RouteNames.businessProfileSettings),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified),
              title: Text(t('License')),
              subtitle: Text(t('USB-C lifetime license status')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RouteNames.businessLicense),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup),
              title: Text(t('Backup & Restore')),
              subtitle: Text(t('Save and restore data from USB-C')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RouteNames.businessBackup),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Customer View'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<BusinessClientsViewMode>(
                    segments: [
                      ButtonSegment(
                        value: BusinessClientsViewMode.grid,
                        icon: Icon(Icons.grid_view),
                        label: Text(t('Grid')),
                      ),
                      ButtonSegment(
                        value: BusinessClientsViewMode.list,
                        icon: Icon(Icons.view_agenda),
                        label: Text(t('List')),
                      ),
                    ],
                    selected: {current.businessClientsViewMode},
                    onSelectionChanged: (selection) {
                      controller.setBusinessClientsViewMode(selection.single);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('Zoom'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SegmentedButton<AppZoomMode>(
                    segments: [
                      ButtonSegment(
                        value: AppZoomMode.normal,
                        icon: Icon(Icons.text_fields),
                        label: Text(t('Normal')),
                      ),
                      ButtonSegment(
                        value: AppZoomMode.large,
                        icon: Icon(Icons.format_size),
                        label: Text(t('Large')),
                      ),
                    ],
                    selected: {current.zoomMode},
                    onSelectionChanged: (selection) {
                      controller.setZoomMode(selection.single);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.dark_mode),
              title: Text(t('Dark Mode')),
              value: current.darkMode,
              onChanged: controller.setDarkMode,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.share),
              title: Text(t('Referral Program')),
              subtitle: Text(
                t('Let customers refer a friend for a reward on their loyalty card'),
              ),
              value: business.valueOrNull?.referralProgramEnabled ?? false,
              onChanged: business.valueOrNull == null
                  ? null
                  : (enabled) => ref
                        .read(businessProfileControllerProvider.notifier)
                        .setReferralProgramEnabled(enabled),
            ),
          ),
          const SizedBox(height: 12),
          const LanguageTile(),          const SizedBox(height: 12),
          const ChangeAppModeTile(currentMode: AppMode.business),
        ],
      ),
    );
  }
}

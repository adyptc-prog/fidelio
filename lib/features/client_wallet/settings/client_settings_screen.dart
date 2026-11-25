import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../app/providers/app_settings_providers.dart';
import '../../../app/providers/client_wallet_providers.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/value_objects/app_mode.dart';
import '../../../presentation/layouts/section_shell.dart';
import '../../../presentation/widgets/change_app_mode_tile.dart';
import 'package:fidelio/app/localization/app_language.dart';
import 'package:fidelio/presentation/widgets/language_tile.dart';

class ClientSettingsScreen extends ConsumerWidget {
  const ClientSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final walletId = ref.watch(clientWalletIdProvider);
    final current =
        settings.valueOrNull ?? const AppSettings(selectedMode: null);
    final controller = ref.read(appSettingsControllerProvider.notifier);

    return SectionShell(
      title: t('Settings Client'),
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Card View'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ClientCardsViewMode>(
                    segments: [
                      ButtonSegment(
                        value: ClientCardsViewMode.grid,
                        icon: Icon(Icons.grid_view),
                        label: Text(t('Grid')),
                      ),
                      ButtonSegment(
                        value: ClientCardsViewMode.list,
                        icon: Icon(Icons.view_agenda),
                        label: Text(t('List')),
                      ),
                    ],
                    selected: {current.clientCardsViewMode},
                    onSelectionChanged: (selection) {
                      controller.setClientCardsViewMode(selection.single);
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: walletId.when(
                data: (value) => Row(
                  children: [
                    const Icon(Icons.account_balance_wallet),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('Wallet ID'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            value,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: t('Copy Wallet ID'),
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: value));
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t('Wallet ID copied.'))),
                        );
                      },
                    ),
                  ],
                ),
                loading: () => ListTile(
                  leading: Icon(Icons.account_balance_wallet),
                  title: Text(t('Wallet ID')),
                  subtitle: Text(t('Loading...')),
                ),
                error: (error, stackTrace) => ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(t('Wallet ID')),
                  subtitle: Text(tr('ID-ul portofelului nu a putut fi încărcat: $error', 'Could not load wallet ID: $error')),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const LanguageTile(),          const SizedBox(height: 12),
          ChangeAppModeTile(currentMode: AppMode.client),
        ],
      ),
    );
  }
}

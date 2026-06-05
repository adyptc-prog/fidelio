import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../app/providers/app_settings_providers.dart';
import '../../../app/providers/client_wallet_providers.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/value_objects/app_mode.dart';
import '../../../presentation/layouts/section_shell.dart';
import '../../../presentation/widgets/change_app_mode_tile.dart';

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
      title: 'Settings Client',
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Card View',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ClientCardsViewMode>(
                    segments: const [
                      ButtonSegment(
                        value: ClientCardsViewMode.grid,
                        icon: Icon(Icons.grid_view),
                        label: Text('Grid'),
                      ),
                      ButtonSegment(
                        value: ClientCardsViewMode.list,
                        icon: Icon(Icons.view_agenda),
                        label: Text('List'),
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
                  Text('Zoom', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SegmentedButton<AppZoomMode>(
                    segments: const [
                      ButtonSegment(
                        value: AppZoomMode.normal,
                        icon: Icon(Icons.text_fields),
                        label: Text('Normal'),
                      ),
                      ButtonSegment(
                        value: AppZoomMode.large,
                        icon: Icon(Icons.format_size),
                        label: Text('Large'),
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
              title: const Text('Dark Mode'),
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
                            'Wallet ID',
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
                      tooltip: 'Copy Wallet ID',
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: value));
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Wallet ID copied.')),
                        );
                      },
                    ),
                  ],
                ),
                loading: () => const ListTile(
                  leading: Icon(Icons.account_balance_wallet),
                  title: Text('Wallet ID'),
                  subtitle: Text('Loading...'),
                ),
                error: (error, stackTrace) => ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: const Text('Wallet ID'),
                  subtitle: Text('Could not load wallet ID: $error'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ChangeAppModeTile(currentMode: AppMode.client),
        ],
      ),
    );
  }
}

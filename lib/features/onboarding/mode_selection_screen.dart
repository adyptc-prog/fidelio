import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../app/providers/app_settings_providers.dart';
import '../../core/constants/route_names.dart';
import '../../domain/value_objects/app_mode.dart';
import '../../presentation/widgets/menu_tile.dart';

class ModeSelectionScreen extends ConsumerWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.appName)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choose how to use the app',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  MenuTile(
                    title: AppStrings.businessMode,
                    subtitle:
                        'Local management for customers, memberships, loyalty and backup.',
                    icon: Icons.storefront,
                    onTap: () => _selectMode(context, ref, AppMode.business),
                  ),
                  const SizedBox(height: 12),
                  MenuTile(
                    title: AppStrings.clientMode,
                    subtitle: 'Local wallet for digital cards and dynamic QR.',
                    icon: Icons.account_balance_wallet,
                    onTap: () => _selectMode(context, ref, AppMode.client),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectMode(
    BuildContext context,
    WidgetRef ref,
    AppMode mode,
  ) async {
    await ref.read(appSettingsControllerProvider.notifier).selectMode(mode);
    if (!context.mounted) {
      return;
    }

    context.go(
      mode == AppMode.business
          ? RouteNames.businessDashboard
          : RouteNames.clientWallet,
    );
  }
}

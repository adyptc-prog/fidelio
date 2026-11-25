import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/app_settings_providers.dart';
import '../../core/constants/route_names.dart';
import '../../domain/value_objects/app_mode.dart';
import 'package:fidelio/app/localization/app_language.dart';

class ChangeAppModeTile extends ConsumerWidget {
  const ChangeAppModeTile({required this.currentMode, super.key});

  final AppMode currentMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetMode = currentMode == AppMode.business
        ? AppMode.client
        : AppMode.business;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.swap_horiz),
        title: Text(t('Change app mode')),
        subtitle: Text(tr('Modul curent: ${_modeLabel(currentMode)}', 'Current mode: ${_modeLabel(currentMode)}')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _confirmAndChange(context, ref, targetMode),
      ),
    );
  }

  Future<void> _confirmAndChange(
    BuildContext context,
    WidgetRef ref,
    AppMode targetMode,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Change app mode?')),
        content: Text(
          tr('Vei trece la ${_modeLabel(targetMode)}. Datele locale existente nu se șterg.', 'You will switch to ${_modeLabel(targetMode)}. Existing local data will not be deleted.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t('Confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    await ref
        .read(appSettingsControllerProvider.notifier)
        .selectMode(targetMode);

    if (!context.mounted) {
      return;
    }

    context.go(
      targetMode == AppMode.business
          ? RouteNames.businessDashboard
          : RouteNames.clientWallet,
    );
  }
}

String _modeLabel(AppMode mode) {
  return switch (mode) {
    AppMode.business => t('Business'),
    AppMode.client => t('Client'),
  };
}

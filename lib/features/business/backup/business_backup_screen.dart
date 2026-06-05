import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/backup_providers.dart';
import '../../../app/providers/business_profile_providers.dart';
import '../../../presentation/layouts/section_shell.dart';

class BusinessBackupScreen extends ConsumerStatefulWidget {
  const BusinessBackupScreen({super.key});

  @override
  ConsumerState<BusinessBackupScreen> createState() =>
      _BusinessBackupScreenState();
}

class _BusinessBackupScreenState extends ConsumerState<BusinessBackupScreen> {
  bool _isBusy = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(businessProfileControllerProvider);
    final folder = ref.watch(backupFolderProvider);

    return SectionShell(
      title: 'Backup & Restore',
      child: business.when(
        data: (business) {
          if (business == null) {
            return const Center(
              child: Text('Business profile is not configured.'),
            );
          }

          return ListView(
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.folder),
                  title: const Text('USB Backup Folder'),
                  subtitle: Text(
                    folder.when(
                      data: (value) => value ?? 'No USB backup folder selected',
                      loading: () => 'Loading folder...',
                      error: (error, stackTrace) => 'Folder unavailable',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Select USB Backup Folder'),
                onPressed: _isBusy ? null : _selectFolder,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.backup),
                label: const Text('Create Backup on USB'),
                onPressed: _isBusy
                    ? null
                    : () => _createBackup(
                        businessId: business.businessId,
                        businessName: business.displayName,
                      ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.restore),
                label: const Text('Restore Backup from USB'),
                onPressed: _isBusy ? null : _confirmRestoreFromPicker,
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_message!, textAlign: TextAlign.center),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Restore opens the USB picker so you can choose a .fideliobackup file directly.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Could not load business: $error')),
      ),
    );
  }

  Future<void> _selectFolder() async {
    setState(() {
      _isBusy = true;
      _message = null;
    });
    try {
      await ref.read(usbBackupServiceProvider).pickBackupFolder();
      ref.invalidate(backupFolderProvider);
      setState(() => _message = 'Backup folder selected.');
    } on Object catch (error) {
      setState(() => _message = 'Could not select folder: $error');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _createBackup({
    required String businessId,
    required String businessName,
  }) async {
    setState(() {
      _isBusy = true;
      _message = 'Creating backup...';
    });
    try {
      final backup = await ref
          .read(usbBackupServiceProvider)
          .createBackup(businessId: businessId, businessName: businessName);
      setState(() => _message = 'Backup created: ${backup.name}');
    } on Object catch (error) {
      setState(() => _message = 'Could not create backup: $error');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _confirmRestoreFromPicker() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'This will replace all local data with the selected USB backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _restoreFromPicker();
    }
  }

  Future<void> _restoreFromPicker() async {
    setState(() {
      _isBusy = true;
      _message = 'Select the backup file from USB...';
    });
    try {
      await ref.read(backupRestoreControllerProvider).pickAndRestoreBackup();
      setState(
        () => _message = 'Backup restored. Local data has been reloaded.',
      );
    } on Object catch (error) {
      setState(() => _message = 'Could not restore backup: $error');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }
}

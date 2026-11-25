import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/backup_providers.dart';
import '../../../app/providers/business_profile_providers.dart';
import '../../../presentation/layouts/section_shell.dart';
import 'package:fidelio/app/localization/app_language.dart';

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
      title: t('Backup & Restore'),
      child: business.when(
        data: (business) {
          if (business == null) {
            return Center(
              child: Text(t('Business profile is not configured.')),
            );
          }

          return ListView(
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(t('USB Backup Folder')),
                  subtitle: Text(
                    folder.when(
                      data: (value) => value == null
                          ? t('No USB backup folder selected')
                          : displayBackupFolder(value),
                      loading: () => t('Loading folder...'),
                      error: (error, stackTrace) => t('Folder unavailable'),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.folder_open),
                label: Text(t('Select USB Backup Folder')),
                onPressed: _isBusy ? null : _selectFolder,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.backup),
                label: Text(t('Create Backup on USB')),
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
                label: Text(t('Restore Backup from USB')),
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
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    t('Restore opens the USB picker so you can choose a .fideliobackup file directly.'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text(tr('Nu s-a putut încărca afacerea: $error', 'Could not load business: $error'))),
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
      setState(() => _message = t('Backup folder selected.'));
    } on Object catch (error) {
      setState(() => _message = tr('Nu s-a putut alege folderul: $error', 'Could not select folder: $error'));
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
      _message = t('Creating backup...');
    });
    try {
      final backup = await ref
          .read(usbBackupServiceProvider)
          .createBackup(businessId: businessId, businessName: businessName);
      setState(() => _message = tr('Backup creat: ${backup.name}', 'Backup created: ${backup.name}'));
    } on Object catch (error) {
      setState(() => _message = tr('Nu s-a putut crea backup-ul: ${friendlyBackupError(error)}', 'Could not create backup: ${friendlyBackupError(error)}'));
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
        title: Text(t('Restore backup?')),
        content: Text(
          t('This will replace all local data with the selected USB backup.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t('Restore')),
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
      _message = t('Select the backup file from USB...');
    });
    try {
      await ref.read(backupRestoreControllerProvider).pickAndRestoreBackup();
      setState(
        () => _message = t('Backup restored. Local data has been reloaded.'),
      );
    } on Object catch (error) {
      setState(() => _message = tr('Nu s-a putut restaura backup-ul: ${friendlyBackupError(error)}', 'Could not restore backup: ${friendlyBackupError(error)}'));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }
}

/// Mesajul pentru utilizator, fără „PlatformException(COD, ...)”.
String friendlyBackupError(Object error) {
  if (error is PlatformException) {
    final message = error.message?.trim() ?? '';
    return message.isEmpty ? error.code : message;
  }
  return error.toString().replaceFirst(RegExp(r'^(Exception|StateError): '), '');
}

/// „content://…/tree/primary%3ADocuments%2FFidelioBackup” → „Documents/FidelioBackup”.
String displayBackupFolder(String uri) {
  final marker = uri.indexOf('/tree/');
  if (!uri.startsWith('content://') || marker == -1) return uri;
  final decoded = Uri.decodeComponent(uri.substring(marker + 6));
  final colon = decoded.indexOf(':');
  if (colon == -1) return decoded;
  final volume = decoded.substring(0, colon);
  final path = decoded.substring(colon + 1);
  if (volume == 'primary') return path.isEmpty ? t('Phone storage') : path;
  return path.isEmpty ? 'USB ($volume)' : 'USB ($volume): $path';
}

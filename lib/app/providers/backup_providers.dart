import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_db/app_database.dart';
import '../../data/services/android_usb_backup_service.dart';
import '../../domain/entities/usb_backup_entry.dart';
import 'app_settings_providers.dart';
import 'business_check_in_providers.dart';
import 'business_customers_providers.dart';
import 'business_profile_providers.dart';
import 'business_subscriptions_providers.dart';

final usbBackupServiceProvider = Provider<AndroidUsbBackupService>((ref) {
  return const AndroidUsbBackupService();
});

final backupFolderProvider = FutureProvider<String?>((ref) {
  return ref.watch(usbBackupServiceProvider).getBackupFolder();
});

final usbBackupsProvider = FutureProvider<List<UsbBackupEntry>>((ref) {
  return ref.watch(usbBackupServiceProvider).listBackups();
});

final backupRestoreControllerProvider = Provider<BackupRestoreController>((
  ref,
) {
  return BackupRestoreController(ref);
});

class BackupRestoreController {
  const BackupRestoreController(this._ref);

  final Ref _ref;

  Future<void> pickAndRestoreBackup() async {
    await _ref.read(usbBackupServiceProvider).pickAndRestoreBackup();
    _invalidateLocalData();
  }

  void _invalidateLocalData() {
    final businessId =
        _ref.read(businessProfileControllerProvider).valueOrNull?.businessId;

    _ref.invalidate(appDatabaseProvider);
    _ref.invalidate(appSettingsControllerProvider);
    _ref.invalidate(businessProfileControllerProvider);
    _ref.invalidate(businessCustomersControllerProvider);
    _ref.invalidate(backupFolderProvider);
    _ref.invalidate(usbBackupsProvider);

    if (businessId == null) {
      return;
    }
    _ref.invalidate(businessCardCountProvider(businessId));
    _ref.invalidate(businessSubscriptionCardsProvider(businessId));
    _ref.invalidate(businessLoyaltyCardsProvider(businessId));
    _ref.invalidate(businessCheckInsProvider(businessId));
  }
}

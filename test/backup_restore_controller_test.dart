import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fidelio/app/providers/app_settings_providers.dart';
import 'package:fidelio/app/providers/backup_providers.dart';
import 'package:fidelio/data/local_db/app_database.dart';
import 'package:fidelio/data/services/android_usb_backup_service.dart';

class _FakeUsbBackupService extends AndroidUsbBackupService {
  _FakeUsbBackupService();

  var restored = false;

  @override
  Future<void> pickAndRestoreBackup() async {
    restored = true;
  }
}

void main() {
  test(
    'backup restore controller restores and invalidates local providers',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final backupService = _FakeUsbBackupService();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          usbBackupServiceProvider.overrideWithValue(backupService),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appSettingsControllerProvider.future);

      await container
          .read(backupRestoreControllerProvider)
          .pickAndRestoreBackup();

      expect(backupService.restored, isTrue);
      expect(container.read(appSettingsControllerProvider).isLoading, isTrue);
    },
  );
}

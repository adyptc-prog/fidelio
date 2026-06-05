import '../entities/backup_info.dart';

abstract interface class BackupService {
  Future<BackupInfo> createLocalBackup({required String destinationPath});

  Future<void> restoreLocalBackup(String backupPath);

  Future<List<BackupInfo>> listKnownBackups();
}

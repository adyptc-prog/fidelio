class BackupInfo {
  const BackupInfo({
    required this.backupId,
    required this.createdAt,
    required this.path,
    required this.checksum,
    this.businessId,
  });

  final String backupId;
  final DateTime createdAt;
  final String path;
  final String checksum;
  final String? businessId;
}

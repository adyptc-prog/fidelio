class UsbBackupEntry {
  const UsbBackupEntry({
    required this.id,
    required this.name,
    required this.modifiedAt,
    required this.size,
    this.checksum,
  });

  final String id;
  final String name;
  final DateTime modifiedAt;
  final int size;
  final String? checksum;

  factory UsbBackupEntry.fromJson(Map<Object?, Object?> json) {
    return UsbBackupEntry(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['modifiedAt'] as int?) ?? 0,
      ),
      size: (json['size'] as int?) ?? 0,
      checksum: json['checksum'] as String?,
    );
  }
}

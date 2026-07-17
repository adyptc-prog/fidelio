enum LicenseState { active, missing, invalid }

class LicenseStatus {
  const LicenseStatus({
    required this.state,
    required this.message,
    this.path,
    this.licenseId,
    this.stickId,
    this.isLifetime,
    this.validUntil,
    this.daysUntilExpiry,
  });

  final LicenseState state;
  final String message;
  final String? path;
  final String? licenseId;
  final String? stickId;
  final bool? isLifetime;
  final String? validUntil;
  final int? daysUntilExpiry;

  bool get isActive => state == LicenseState.active;

  bool get isExpiringSoon =>
      state == LicenseState.active &&
      isLifetime == false &&
      daysUntilExpiry != null &&
      daysUntilExpiry! <= 10;

  factory LicenseStatus.fromJson(Map<Object?, Object?> json) {
    final status = json['status'] as String? ?? 'missing';
    return LicenseStatus(
      state: switch (status) {
        'active' => LicenseState.active,
        'invalid' => LicenseState.invalid,
        _ => LicenseState.missing,
      },
      message: json['message'] as String? ?? '',
      path: json['path'] as String?,
      licenseId: json['licenseId'] as String?,
      stickId: json['stickId'] as String?,
      isLifetime: json['isLifetime'] as bool?,
      validUntil: json['validUntil'] as String?,
      daysUntilExpiry: json['daysUntilExpiry'] as int?,
    );
  }
}

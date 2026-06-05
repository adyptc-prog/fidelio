enum LicenseState { active, missing, invalid }

class LicenseStatus {
  const LicenseStatus({
    required this.state,
    required this.message,
    this.path,
    this.licenseId,
    this.stickId,
  });

  final LicenseState state;
  final String message;
  final String? path;
  final String? licenseId;
  final String? stickId;

  bool get isActive => state == LicenseState.active;

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
    );
  }
}

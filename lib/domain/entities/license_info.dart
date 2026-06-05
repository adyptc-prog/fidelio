class LicenseInfo {
  const LicenseInfo({
    required this.licenseId,
    required this.businessId,
    required this.issuedAt,
    required this.isLifetime,
    required this.signature,
    this.validUntil,
    this.sourcePath,
  });

  final String licenseId;
  final String businessId;
  final DateTime issuedAt;
  final bool isLifetime;
  final String signature;
  final DateTime? validUntil;
  final String? sourcePath;
}

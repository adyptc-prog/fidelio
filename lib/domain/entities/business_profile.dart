class BusinessProfile {
  const BusinessProfile({
    required this.businessId,
    required this.displayName,
    required this.createdAt,
    this.activityDomain,
    this.phone,
    this.email,
    this.address,
    this.cardAccentColor,
    this.activitySymbol,
    this.localPublicKey,
  });

  final String businessId;
  final String displayName;
  final DateTime createdAt;
  final String? activityDomain;
  final String? phone;
  final String? email;
  final String? address;
  final int? cardAccentColor;
  final String? activitySymbol;
  final String? localPublicKey;
}

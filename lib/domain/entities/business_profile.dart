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
    this.referralProgramEnabled = false,
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

  /// Whether customers can refer a friend for a reward on their loyalty
  /// cards from this business.
  final bool referralProgramEnabled;
}

class SubscriptionImportPayload {
  const SubscriptionImportPayload({
    required this.type,
    required this.version,
    required this.businessId,
    required this.businessName,
    required this.clientId,
    required this.subscriptionId,
    required this.cardTitle,
    required this.validFrom,
    required this.validUntil,
    required this.issuedAt,
    this.businessDomain,
    this.businessSymbol,
    this.businessAccentColor,
    this.cardType = 'subscription',
    this.entriesTotal,
    this.entriesRemaining,
    this.scanValue,
    this.programType,
    this.challengeWindowDays,
    this.referrerCardId,
    this.referralProgramEnabled = false,
    this.signature,
  });

  final String type;
  final int version;
  final String businessId;
  final String businessName;
  final String? businessDomain;
  final String? businessSymbol;
  final int? businessAccentColor;
  final String clientId;
  final String subscriptionId;
  final String cardTitle;
  final DateTime validFrom;
  final DateTime validUntil;
  final String cardType;
  final int? entriesTotal;
  final int? entriesRemaining;
  final int? scanValue;

  /// Loyalty program type name (e.g. 'stamps', 'points', 'visitChallenge',
  /// 'delivery'), carried so a referred card can be recreated faithfully.
  final String? programType;

  /// Only meaningful for `visitChallenge` cards.
  final int? challengeWindowDays;

  /// Set when this payload is a referral invite: the card id of the
  /// customer who shared it, so the business can reward them on redemption.
  final String? referrerCardId;

  /// Whether the issuing business currently has the referral program
  /// enabled. Mirrored onto the client's wallet card so it knows whether to
  /// offer a "Refer a Friend" action.
  final bool referralProgramEnabled;

  final DateTime issuedAt;
  final String? signature;

  bool get isReferralInvite => referrerCardId != null;

  SubscriptionImportPayload copyWith({String? signature}) {
    return SubscriptionImportPayload(
      type: type,
      version: version,
      businessId: businessId,
      businessName: businessName,
      clientId: clientId,
      subscriptionId: subscriptionId,
      cardTitle: cardTitle,
      validFrom: validFrom,
      validUntil: validUntil,
      issuedAt: issuedAt,
      businessDomain: businessDomain,
      businessSymbol: businessSymbol,
      businessAccentColor: businessAccentColor,
      cardType: cardType,
      entriesTotal: entriesTotal,
      entriesRemaining: entriesRemaining,
      scanValue: scanValue,
      programType: programType,
      challengeWindowDays: challengeWindowDays,
      referrerCardId: referrerCardId,
      referralProgramEnabled: referralProgramEnabled,
      signature: signature ?? this.signature,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'type': type,
      'version': version,
      'businessId': businessId,
      'businessName': businessName,
      'businessDomain': businessDomain,
      'businessSymbol': businessSymbol,
      'businessAccentColor': businessAccentColor,
      'clientId': clientId,
      'subscriptionId': subscriptionId,
      'cardTitle': cardTitle,
      'validFrom': validFrom.toUtc().toIso8601String(),
      'validUntil': validUntil.toUtc().toIso8601String(),
      'cardType': cardType,
      'entriesTotal': entriesTotal,
      'entriesRemaining': entriesRemaining,
      'scanValue': scanValue,
      'programType': programType,
      'challengeWindowDays': challengeWindowDays,
      'referrerCardId': referrerCardId,
      'referralProgramEnabled': referralProgramEnabled,
      'issuedAt': issuedAt.toUtc().toIso8601String(),
      'signature': signature,
    };
  }

  factory SubscriptionImportPayload.fromJson(Map<String, Object?> json) {
    return SubscriptionImportPayload(
      type: json['type'] as String? ?? '',
      version: json['version'] as int? ?? 0,
      businessId: json['businessId'] as String? ?? '',
      businessName: json['businessName'] as String? ?? '',
      businessDomain: json['businessDomain'] as String?,
      businessSymbol: json['businessSymbol'] as String?,
      businessAccentColor: json['businessAccentColor'] as int?,
      clientId: json['clientId'] as String? ?? '',
      subscriptionId: json['subscriptionId'] as String? ?? '',
      cardTitle: json['cardTitle'] as String? ?? '',
      validFrom: _parseDate(json['validFrom']),
      validUntil: _parseDate(json['validUntil']),
      cardType: json['cardType'] as String? ?? 'subscription',
      entriesTotal: json['entriesTotal'] as int?,
      entriesRemaining: json['entriesRemaining'] as int?,
      scanValue: json['scanValue'] as int?,
      programType: json['programType'] as String?,
      challengeWindowDays: json['challengeWindowDays'] as int?,
      referrerCardId: json['referrerCardId'] as String?,
      referralProgramEnabled: json['referralProgramEnabled'] as bool? ?? false,
      issuedAt: _parseDate(json['issuedAt']),
      signature: json['signature'] as String?,
    );
  }

  static DateTime _parseDate(Object? value) {
    if (value is! String) {
      throw const FormatException('Invalid date field in QR payload.');
    }
    return DateTime.parse(value);
  }
}

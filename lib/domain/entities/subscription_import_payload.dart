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
  final DateTime issuedAt;
  final String? signature;

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

import '../value_objects/card_status.dart';

class WalletCard {
  const WalletCard({
    required this.walletCardId,
    required this.walletId,
    required this.businessId,
    required this.cardId,
    required this.cardType,
    required this.displayName,
    required this.createdAt,
    required this.status,
    this.businessName,
    this.businessDomain,
    this.businessSymbol,
    this.businessAccentColor,
    this.entriesTotal,
    this.entriesRemaining,
    this.scanValue,
    this.validUntil,
    this.dynamicChallenge,
    this.challengeTimestamp,
    this.challengeSignature,
  });

  final String walletCardId;
  final String walletId;
  final String businessId;
  final String cardId;
  final String cardType;
  final String displayName;
  final DateTime createdAt;
  final CardStatus status;
  final String? businessName;
  final String? businessDomain;
  final String? businessSymbol;
  final int? businessAccentColor;
  final int? entriesTotal;
  final int? entriesRemaining;
  final int? scanValue;
  final DateTime? validUntil;
  final String? dynamicChallenge;
  final DateTime? challengeTimestamp;
  final String? challengeSignature;

  WalletCard copyWith({
    int? entriesRemaining,
    int? scanValue,
    DateTime? challengeTimestamp,
  }) {
    return WalletCard(
      walletCardId: walletCardId,
      walletId: walletId,
      businessId: businessId,
      cardId: cardId,
      cardType: cardType,
      displayName: displayName,
      createdAt: createdAt,
      status: status,
      businessName: businessName,
      businessDomain: businessDomain,
      businessSymbol: businessSymbol,
      businessAccentColor: businessAccentColor,
      entriesTotal: entriesTotal,
      entriesRemaining: entriesRemaining ?? this.entriesRemaining,
      scanValue: scanValue ?? this.scanValue,
      validUntil: validUntil,
      dynamicChallenge: dynamicChallenge,
      challengeTimestamp: challengeTimestamp ?? this.challengeTimestamp,
      challengeSignature: challengeSignature,
    );
  }
}

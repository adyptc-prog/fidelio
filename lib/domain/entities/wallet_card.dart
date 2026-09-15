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
    this.programType,
    this.challengeWindowDays,
    this.referralEnabled = false,
    this.referrerCardId,
    this.pendingActivation = false,
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

  /// Loyalty program type name (e.g. 'stamps', 'points', 'visitChallenge',
  /// 'delivery'). Null for subscription/membership cards.
  final String? programType;

  /// Only meaningful for `visitChallenge` loyalty cards.
  final int? challengeWindowDays;

  /// Whether the issuing business currently allows referring a friend from
  /// this card.
  final bool referralEnabled;

  /// Set when this card was received as a referral: the card id of the
  /// friend who shared it. Kept as provenance even after activation.
  final String? referrerCardId;

  /// True for a referral-received card that hasn't been scanned in by the
  /// business yet (it doesn't exist in the business's database until then).
  final bool pendingActivation;

  WalletCard copyWith({
    int? entriesRemaining,
    int? scanValue,
    DateTime? challengeTimestamp,
    bool? pendingActivation,
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
      programType: programType,
      challengeWindowDays: challengeWindowDays,
      referralEnabled: referralEnabled,
      referrerCardId: referrerCardId,
      pendingActivation: pendingActivation ?? this.pendingActivation,
    );
  }
}

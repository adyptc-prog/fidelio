import '../value_objects/card_status.dart';
import '../value_objects/subscription_type.dart';

class SubscriptionCard {
  const SubscriptionCard({
    required this.businessId,
    required this.cardId,
    required this.customerId,
    required this.name,
    required this.createdAt,
    required this.status,
    this.subscriptionType = SubscriptionType.custom,
    this.startsAt,
    this.expiresAt,
    this.notes,
    this.validUntil,
    this.remainingUses,
    this.linkedWalletId,
    this.dynamicChallenge,
    this.challengeTimestamp,
    this.challengeSignature,
  });

  final String businessId;
  final String cardId;
  final String customerId;
  final String name;
  final DateTime createdAt;
  final CardStatus status;
  final SubscriptionType subscriptionType;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final String? notes;
  final DateTime? validUntil;
  final int? remainingUses;
  final String? linkedWalletId;
  final String? dynamicChallenge;
  final DateTime? challengeTimestamp;
  final String? challengeSignature;

  CardStatus get effectiveStatus {
    if (status == CardStatus.active &&
        expiresAt != null &&
        expiresAt!.isBefore(DateTime.now())) {
      return CardStatus.expired;
    }
    return status;
  }
}

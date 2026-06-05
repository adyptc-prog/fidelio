import '../value_objects/card_status.dart';
import '../value_objects/loyalty_program_type.dart';

class LoyaltyCard {
  const LoyaltyCard({
    required this.businessId,
    required this.cardId,
    required this.customerId,
    required this.name,
    required this.createdAt,
    required this.status,
    required this.currentStamps,
    required this.rewardThreshold,
    this.programType = LoyaltyProgramType.stamps,
    this.pointsPerScan,
    this.challengeWindowDays,
    this.challengeStartedAt,
    this.validUntil,
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
  final int currentStamps;
  final int rewardThreshold;
  final LoyaltyProgramType programType;
  final int? pointsPerScan;
  final int? challengeWindowDays;
  final DateTime? challengeStartedAt;
  final DateTime? validUntil;
  final String? linkedWalletId;
  final String? dynamicChallenge;
  final DateTime? challengeTimestamp;
  final String? challengeSignature;
}

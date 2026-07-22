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
    this.isBonusPending = false,
    this.isCompleted = false,
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

  /// True once the regular entries are used up and the next entry is the
  /// bonus one.
  final bool isBonusPending;

  /// True once the bonus entry has also been consumed. A completed card can
  /// no longer be used for check-ins; a new card must be created.
  final bool isCompleted;

  LoyaltyCard copyWith({
    CardStatus? status,
    int? currentStamps,
    DateTime? challengeStartedAt,
    String? linkedWalletId,
    String? dynamicChallenge,
    DateTime? challengeTimestamp,
    String? challengeSignature,
    bool? isBonusPending,
    bool? isCompleted,
  }) {
    return LoyaltyCard(
      businessId: businessId,
      cardId: cardId,
      customerId: customerId,
      name: name,
      createdAt: createdAt,
      status: status ?? this.status,
      currentStamps: currentStamps ?? this.currentStamps,
      rewardThreshold: rewardThreshold,
      programType: programType,
      pointsPerScan: pointsPerScan,
      challengeWindowDays: challengeWindowDays,
      challengeStartedAt: challengeStartedAt ?? this.challengeStartedAt,
      validUntil: validUntil,
      linkedWalletId: linkedWalletId ?? this.linkedWalletId,
      dynamicChallenge: dynamicChallenge ?? this.dynamicChallenge,
      challengeTimestamp: challengeTimestamp ?? this.challengeTimestamp,
      challengeSignature: challengeSignature ?? this.challengeSignature,
      isBonusPending: isBonusPending ?? this.isBonusPending,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

import '../entities/loyalty_card.dart';
import '../value_objects/loyalty_program_type.dart';

enum LoyaltyProgressOutcome { normal, thresholdReached, bonusConsumed }

/// The result of advancing a loyalty card's progress by one entry (a scan or
/// a manually granted bonus such as a birthday reward).
class LoyaltyProgressUpdate {
  const LoyaltyProgressUpdate({
    required this.value,
    required this.challengeStartedAt,
    this.outcome = LoyaltyProgressOutcome.normal,
  });

  final int value;
  final DateTime? challengeStartedAt;
  final LoyaltyProgressOutcome outcome;
}

/// Advances [card]'s progress by one entry, honoring its program type
/// (stamps, points, visit challenge, delivery). Used both for a validated
/// check-in scan and for manually granted bonuses (e.g. birthday rewards).
LoyaltyProgressUpdate advanceLoyaltyProgress(LoyaltyCard card, DateTime at) {
  return switch (card.programType) {
    LoyaltyProgramType.stamps ||
    LoyaltyProgramType.delivery => _stampProgress(card),
    LoyaltyProgramType.points => _pointsProgress(card),
    LoyaltyProgramType.visitChallenge => _visitChallengeProgress(card, at),
  };
}

LoyaltyProgressUpdate _stampProgress(LoyaltyCard card) {
  if (card.isBonusPending) {
    return LoyaltyProgressUpdate(
      value: card.currentStamps + 1,
      challengeStartedAt: card.challengeStartedAt,
      outcome: LoyaltyProgressOutcome.bonusConsumed,
    );
  }
  final newValue = card.currentStamps + 1;
  final earned = newValue >= card.rewardThreshold;
  return LoyaltyProgressUpdate(
    value: newValue,
    challengeStartedAt: card.challengeStartedAt,
    outcome: earned
        ? LoyaltyProgressOutcome.thresholdReached
        : LoyaltyProgressOutcome.normal,
  );
}

LoyaltyProgressUpdate _pointsProgress(LoyaltyCard card) {
  if (card.isBonusPending) {
    return LoyaltyProgressUpdate(
      value: card.currentStamps + (card.pointsPerScan ?? 10),
      challengeStartedAt: card.challengeStartedAt,
      outcome: LoyaltyProgressOutcome.bonusConsumed,
    );
  }
  final newValue = card.currentStamps + (card.pointsPerScan ?? 10);
  final earned = newValue >= card.rewardThreshold;
  return LoyaltyProgressUpdate(
    value: newValue,
    challengeStartedAt: card.challengeStartedAt,
    outcome: earned
        ? LoyaltyProgressOutcome.thresholdReached
        : LoyaltyProgressOutcome.normal,
  );
}

LoyaltyProgressUpdate _visitChallengeProgress(LoyaltyCard card, DateTime at) {
  if (card.isBonusPending) {
    return LoyaltyProgressUpdate(
      value: card.currentStamps + 1,
      challengeStartedAt: card.challengeStartedAt,
      outcome: LoyaltyProgressOutcome.bonusConsumed,
    );
  }

  final windowDays = card.challengeWindowDays ?? 30;
  final startedAt = card.challengeStartedAt ?? at;
  final expiresAt = startedAt.add(Duration(days: windowDays));
  if (at.isAfter(expiresAt)) {
    return LoyaltyProgressUpdate(value: 1, challengeStartedAt: at);
  }

  final newValue = card.currentStamps + 1;
  final earned = newValue >= card.rewardThreshold;
  return LoyaltyProgressUpdate(
    value: newValue,
    challengeStartedAt: startedAt,
    outcome: earned
        ? LoyaltyProgressOutcome.thresholdReached
        : LoyaltyProgressOutcome.normal,
  );
}

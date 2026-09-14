import 'package:flutter_test/flutter_test.dart';
import 'package:fidelio/domain/entities/loyalty_card.dart';
import 'package:fidelio/domain/services/loyalty_progress.dart';
import 'package:fidelio/domain/value_objects/card_status.dart';
import 'package:fidelio/domain/value_objects/loyalty_program_type.dart';

void main() {
  group('advanceLoyaltyProgress', () {
    final now = DateTime.utc(2026, 5, 13, 10);

    LoyaltyCard stampsCard({
      int currentStamps = 2,
      int rewardThreshold = 8,
      bool isBonusPending = false,
    }) {
      return LoyaltyCard(
        businessId: 'business-1',
        cardId: 'loyalty-1',
        customerId: 'customer-1',
        name: 'Coffee Loyalty',
        createdAt: now,
        status: CardStatus.active,
        currentStamps: currentStamps,
        rewardThreshold: rewardThreshold,
        isBonusPending: isBonusPending,
      );
    }

    test('stamps: adds one stamp and stays normal below threshold', () {
      final update = advanceLoyaltyProgress(stampsCard(), now);
      expect(update.value, 3);
      expect(update.outcome, LoyaltyProgressOutcome.normal);
    });

    test('stamps: reaching the threshold flags bonus pending', () {
      final update = advanceLoyaltyProgress(
        stampsCard(currentStamps: 7, rewardThreshold: 8),
        now,
      );
      expect(update.value, 8);
      expect(update.outcome, LoyaltyProgressOutcome.thresholdReached);
    });

    test('stamps: consuming the bonus entry completes the card', () {
      final update = advanceLoyaltyProgress(
        stampsCard(currentStamps: 8, rewardThreshold: 8, isBonusPending: true),
        now,
      );
      expect(update.value, 9);
      expect(update.outcome, LoyaltyProgressOutcome.bonusConsumed);
    });

    test('points: adds the configured points per scan', () {
      final card = LoyaltyCard(
        businessId: 'business-1',
        cardId: 'points-1',
        customerId: 'customer-1',
        name: 'Points club',
        createdAt: now,
        status: CardStatus.active,
        currentStamps: 20,
        rewardThreshold: 100,
        programType: LoyaltyProgramType.points,
        pointsPerScan: 15,
      );
      final update = advanceLoyaltyProgress(card, now);
      expect(update.value, 35);
      expect(update.outcome, LoyaltyProgressOutcome.normal);
    });

    test('points: defaults to 10 points when unset', () {
      final card = LoyaltyCard(
        businessId: 'business-1',
        cardId: 'points-1',
        customerId: 'customer-1',
        name: 'Points club',
        createdAt: now,
        status: CardStatus.active,
        currentStamps: 0,
        rewardThreshold: 100,
        programType: LoyaltyProgramType.points,
      );
      final update = advanceLoyaltyProgress(card, now);
      expect(update.value, 10);
    });

    test('delivery: behaves like stamps', () {
      final card = LoyaltyCard(
        businessId: 'business-1',
        cardId: 'delivery-1',
        customerId: 'customer-1',
        name: 'Delivery Pizza',
        createdAt: now,
        status: CardStatus.active,
        currentStamps: 4,
        rewardThreshold: 5,
        programType: LoyaltyProgramType.delivery,
      );
      final update = advanceLoyaltyProgress(card, now);
      expect(update.value, 5);
      expect(update.outcome, LoyaltyProgressOutcome.thresholdReached);
    });

    test('visit challenge: adds a visit within the window', () {
      final card = LoyaltyCard(
        businessId: 'business-1',
        cardId: 'challenge-1',
        customerId: 'customer-1',
        name: '10 visits in 7 days',
        createdAt: now,
        status: CardStatus.active,
        currentStamps: 6,
        rewardThreshold: 10,
        programType: LoyaltyProgramType.visitChallenge,
        challengeWindowDays: 7,
        challengeStartedAt: now,
      );
      final update = advanceLoyaltyProgress(
        card,
        now.add(const Duration(days: 3)),
      );
      expect(update.value, 7);
      expect(update.challengeStartedAt, now);
      expect(update.outcome, LoyaltyProgressOutcome.normal);
    });

    test('visit challenge: resets progress once the window has expired', () {
      final card = LoyaltyCard(
        businessId: 'business-1',
        cardId: 'challenge-1',
        customerId: 'customer-1',
        name: '10 visits in 7 days',
        createdAt: now,
        status: CardStatus.active,
        currentStamps: 6,
        rewardThreshold: 10,
        programType: LoyaltyProgramType.visitChallenge,
        challengeWindowDays: 7,
        challengeStartedAt: now,
      );
      final scanTime = now.add(const Duration(days: 10));
      final update = advanceLoyaltyProgress(card, scanTime);
      expect(update.value, 1);
      expect(update.challengeStartedAt, scanTime);
    });
  });
}

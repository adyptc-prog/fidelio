import 'package:flutter_test/flutter_test.dart';
import 'package:fidelio/domain/entities/subscription_card.dart';
import 'package:fidelio/domain/value_objects/card_status.dart';
import 'package:fidelio/domain/value_objects/subscription_type.dart';

void main() {
  final base = DateTime.utc(2026, 1, 1);

  SubscriptionCard makeCard({
    CardStatus status = CardStatus.active,
    DateTime? expiresAt,
  }) {
    return SubscriptionCard(
      businessId: 'biz-1',
      cardId: 'card-1',
      customerId: 'cust-1',
      name: 'Test',
      createdAt: base,
      status: status,
      expiresAt: expiresAt,
    );
  }

  group('SubscriptionCard.effectiveStatus', () {
    test('active card without expiry stays active', () {
      final card = makeCard(expiresAt: null);
      expect(card.effectiveStatus, CardStatus.active);
    });

    test('active card expiring in far future stays active', () {
      final card = makeCard(expiresAt: DateTime.utc(2099, 12, 31));
      expect(card.effectiveStatus, CardStatus.active);
    });

    test('active card with past expiry returns expired', () {
      final card = makeCard(
        expiresAt: DateTime.now().subtract(const Duration(days: 1)).toUtc(),
      );
      expect(card.effectiveStatus, CardStatus.expired);
    });

    test('suspended card with past expiry stays suspended — not expired', () {
      final card = makeCard(
        status: CardStatus.suspended,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)).toUtc(),
      );
      expect(card.effectiveStatus, CardStatus.suspended);
    });

    test('cancelled card with past expiry stays cancelled', () {
      final card = makeCard(
        status: CardStatus.cancelled,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)).toUtc(),
      );
      expect(card.effectiveStatus, CardStatus.cancelled);
    });
  });

  group('SubscriptionCard fields', () {
    test('remainingUses is nullable and preserved', () {
      final withUses = SubscriptionCard(
        businessId: 'biz-1',
        cardId: 'card-1',
        customerId: 'cust-1',
        name: 'Card',
        createdAt: base,
        status: CardStatus.active,
        subscriptionType: SubscriptionType.entries,
        remainingUses: 5,
      );
      final withoutUses = SubscriptionCard(
        businessId: 'biz-1',
        cardId: 'card-1',
        customerId: 'cust-1',
        name: 'Card',
        createdAt: base,
        status: CardStatus.active,
      );

      expect(withUses.remainingUses, 5);
      expect(withoutUses.remainingUses, isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:fidelio/domain/entities/customer_record.dart';
import 'package:fidelio/domain/services/customer_rank_service.dart';
import 'package:fidelio/domain/value_objects/customer_rank.dart';

void main() {
  group('rankForRewards', () {
    test('0 rewards is entry', () {
      expect(rankForRewards(0), CustomerRank.entry);
    });

    test('1 or 2 rewards is bronze', () {
      expect(rankForRewards(1), CustomerRank.bronze);
      expect(rankForRewards(2), CustomerRank.bronze);
    });

    test('3 to 5 rewards is silver', () {
      expect(rankForRewards(3), CustomerRank.silver);
      expect(rankForRewards(5), CustomerRank.silver);
    });

    test('6 to 8 rewards is gold', () {
      expect(rankForRewards(6), CustomerRank.gold);
      expect(rankForRewards(8), CustomerRank.gold);
    });

    test('9 to 11 rewards is platinum', () {
      expect(rankForRewards(9), CustomerRank.platinum);
      expect(rankForRewards(11), CustomerRank.platinum);
    });

    test('12 or more rewards is vip', () {
      expect(rankForRewards(12), CustomerRank.vip);
      expect(rankForRewards(50), CustomerRank.vip);
    });
  });

  group('sortCustomersByRank', () {
    CustomerRecord customer(String id, int rewards) {
      final now = DateTime(2026, 1, 1);
      return CustomerRecord(
        customerId: id,
        businessId: 'business-1',
        displayName: id,
        createdAt: now,
        updatedAt: now,
        rewardsEarned: rewards,
      );
    }

    test('orders customers by descending reward count', () {
      final sorted = sortCustomersByRank([
        customer('bronze', 1),
        customer('vip', 12),
        customer('gold', 6),
        customer('entry', 0),
      ]);

      expect(sorted.map((c) => c.customerId).toList(), [
        'vip',
        'gold',
        'bronze',
        'entry',
      ]);
    });

    test('breaks ties alphabetically by name', () {
      final sorted = sortCustomersByRank([
        customer('Zoe', 3),
        customer('Ana', 3),
      ]);

      expect(sorted.map((c) => c.customerId).toList(), ['Ana', 'Zoe']);
    });

    test('does not mutate the input list', () {
      final input = [customer('a', 1), customer('b', 5)];
      final sorted = sortCustomersByRank(input);

      expect(sorted, isNot(same(input)));
      expect(input.map((c) => c.customerId).toList(), ['a', 'b']);
    });
  });
}

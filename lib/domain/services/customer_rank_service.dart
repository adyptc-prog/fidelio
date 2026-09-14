import '../entities/customer_record.dart';
import '../value_objects/customer_rank.dart';

/// Maps the number of rewards a customer has earned (a loyalty card
/// reaching its threshold and having the bonus redeemed) to their rank.
CustomerRank rankForRewards(int rewardsEarned) {
  if (rewardsEarned >= 12) {
    return CustomerRank.vip;
  }
  if (rewardsEarned >= 9) {
    return CustomerRank.platinum;
  }
  if (rewardsEarned >= 6) {
    return CustomerRank.gold;
  }
  if (rewardsEarned >= 3) {
    return CustomerRank.silver;
  }
  if (rewardsEarned >= 1) {
    return CustomerRank.bronze;
  }
  return CustomerRank.entry;
}

/// Sorts customers by rank (highest first); customers on the same rank are
/// ordered by their exact reward count, then alphabetically by name.
List<CustomerRecord> sortCustomersByRank(List<CustomerRecord> customers) {
  final sorted = [...customers];
  sorted.sort((a, b) {
    final byRewards = b.rewardsEarned.compareTo(a.rewardsEarned);
    if (byRewards != 0) {
      return byRewards;
    }
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  });
  return sorted;
}

class LoyaltyTransaction {
  const LoyaltyTransaction({
    required this.transactionId,
    required this.businessId,
    required this.cardId,
    required this.createdAt,
    required this.stampDelta,
    this.rewardIssued = false,
    this.note,
  });

  final String transactionId;
  final String businessId;
  final String cardId;
  final DateTime createdAt;
  final int stampDelta;
  final bool rewardIssued;
  final String? note;
}

class CheckInEvent {
  const CheckInEvent({
    required this.eventId,
    required this.businessId,
    required this.cardId,
    required this.occurredAt,
    required this.challengeTimestamp,
    required this.signature,
    this.customerId,
    this.result,
  });

  final String eventId;
  final String businessId;
  final String cardId;
  final DateTime occurredAt;
  final DateTime challengeTimestamp;
  final String signature;
  final String? customerId;
  final String? result;
}

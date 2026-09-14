import '../value_objects/customer_status.dart';

class CustomerRecord {
  const CustomerRecord({
    required this.customerId,
    required this.businessId,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.status = CustomerStatus.active,
    this.phone,
    this.email,
    this.notes,
    this.linkedWalletId,
    this.birthMonth,
    this.birthDay,
    this.lastBirthdayPromptYear,
    this.rewardsEarned = 0,
    this.lastVisitAt,
  });

  final String customerId;
  final String businessId;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CustomerStatus status;
  final String? phone;
  final String? email;
  final String? notes;
  final String? linkedWalletId;

  /// Month of birth (1-12), no year. Null when not set.
  final int? birthMonth;

  /// Day of birth (1-31), no year. Null when not set.
  final int? birthDay;

  /// The calendar year in which the birthday reward prompt was last shown
  /// (accepted or declined) for this customer, used to avoid re-prompting
  /// more than once per year.
  final int? lastBirthdayPromptYear;

  /// Number of loyalty rewards this customer has redeemed at this business
  /// (a card reaching its threshold and the bonus being consumed). Drives
  /// their customer rank (entry/bronze/silver/gold/platinum/vip).
  final int rewardsEarned;

  /// When this customer was last successfully checked in (QR/NFC scan) or
  /// had a delivery stamp added. Null if they have never visited yet.
  final DateTime? lastVisitAt;

  bool get hasBirthday => birthMonth != null && birthDay != null;

  CustomerRecord copyWith({
    String? customerId,
    String? businessId,
    String? displayName,
    DateTime? createdAt,
    DateTime? updatedAt,
    CustomerStatus? status,
    String? phone,
    String? email,
    String? notes,
    String? linkedWalletId,
    int? lastBirthdayPromptYear,
    int? rewardsEarned,
    DateTime? lastVisitAt,
  }) {
    return CustomerRecord(
      customerId: customerId ?? this.customerId,
      businessId: businessId ?? this.businessId,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      linkedWalletId: linkedWalletId ?? this.linkedWalletId,
      birthMonth: birthMonth,
      birthDay: birthDay,
      lastBirthdayPromptYear:
          lastBirthdayPromptYear ?? this.lastBirthdayPromptYear,
      rewardsEarned: rewardsEarned ?? this.rewardsEarned,
      lastVisitAt: lastVisitAt ?? this.lastVisitAt,
    );
  }
}

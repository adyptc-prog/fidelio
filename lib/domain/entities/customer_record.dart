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
    );
  }
}

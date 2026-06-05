class ClientProfile {
  const ClientProfile({
    required this.clientId,
    required this.walletId,
    required this.createdAt,
    this.displayName,
  });

  final String clientId;
  final String walletId;
  final DateTime createdAt;
  final String? displayName;
}

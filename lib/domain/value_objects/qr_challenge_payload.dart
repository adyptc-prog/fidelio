class QrChallengePayload {
  const QrChallengePayload({
    required this.type,
    required this.version,
    required this.walletId,
    required this.cardId,
    required this.dynamicChallenge,
    required this.timestamp,
    required this.signature,
  });

  final String type;
  final int version;
  final String walletId;
  final String cardId;
  final String dynamicChallenge;
  final DateTime timestamp;
  final String signature;

  Map<String, Object?> toJson() {
    return {
      'type': type,
      'version': version,
      'walletId': walletId,
      'cardId': cardId,
      'dynamicChallenge': dynamicChallenge,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'signature': signature,
    };
  }

  factory QrChallengePayload.fromJson(Map<String, Object?> json) {
    return QrChallengePayload(
      type: json['type'] as String? ?? '',
      version: json['version'] as int? ?? 0,
      walletId: json['walletId'] as String? ?? '',
      cardId: json['cardId'] as String? ?? '',
      dynamicChallenge: json['dynamicChallenge'] as String? ?? '',
      timestamp: _parseDate(json['timestamp']),
      signature: json['signature'] as String? ?? '',
    );
  }

  static DateTime _parseDate(Object? value) {
    if (value is! String) {
      throw const FormatException('Invalid date field in QR payload.');
    }
    return DateTime.parse(value);
  }
}

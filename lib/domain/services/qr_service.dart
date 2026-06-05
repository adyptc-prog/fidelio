import '../entities/business_profile.dart';
import '../entities/loyalty_card.dart';
import '../entities/subscription_card.dart';
import '../entities/subscription_import_payload.dart';
import '../value_objects/qr_challenge_payload.dart';

abstract interface class QrService {
  SubscriptionImportPayload createSubscriptionImportPayload({
    required BusinessProfile business,
    required SubscriptionCard subscription,
  });

  SubscriptionImportPayload createLoyaltyImportPayload({
    required BusinessProfile business,
    required LoyaltyCard loyaltyCard,
  });

  String encodeSubscriptionImportPayload(SubscriptionImportPayload payload);

  SubscriptionImportPayload decodeSubscriptionImportPayload(String rawPayload);

  Future<QrChallengePayload> createDynamicChallenge({
    required String walletId,
    required String cardId,
  });

  String encodeDynamicChallenge(QrChallengePayload payload);

  QrChallengePayload decodeDynamicChallenge(String rawPayload);

  Future<bool> verifyDynamicChallenge(QrChallengePayload payload);
}

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/local_qr_service.dart';
import '../../data/repositories/drift_repositories.dart';
import '../../data/repositories/repository_interfaces.dart';
import '../../domain/entities/check_in_event.dart';
import '../../domain/entities/loyalty_card.dart';
import '../../domain/entities/subscription_card.dart';
import '../../domain/services/loyalty_progress.dart';
import '../../domain/value_objects/qr_challenge_payload.dart';
import '../../domain/value_objects/card_status.dart';
import 'app_settings_providers.dart';
import 'business_customers_providers.dart';
import 'business_profile_providers.dart';
import 'business_subscriptions_providers.dart';
import 'qr_providers.dart';

final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  return DriftCheckInRepository(ref.watch(appDatabaseProvider));
});

final businessCheckInsProvider =
    FutureProvider.family<List<CheckInEvent>, String>((ref, businessId) {
      return ref.watch(checkInRepositoryProvider).listCheckIns(businessId);
    });

final businessCheckInControllerProvider = Provider<BusinessCheckInController>((
  ref,
) {
  return BusinessCheckInController(ref);
});

class CheckInScanResult {
  const CheckInScanResult({
    required this.isValid,
    required this.message,
    this.subscription,
  });

  final bool isValid;
  final String message;
  final SubscriptionCard? subscription;
}

class BusinessCheckInController {
  const BusinessCheckInController(this._ref);

  final Ref _ref;

  Future<CheckInScanResult> processRawPayload(String rawPayload) async {
    if (_payloadType(rawPayload) == LocalQrService.dynamicChallengeType) {
      final qrService = _ref.read(qrServiceProvider);
      final payload = qrService.decodeDynamicChallenge(rawPayload);
      return processDynamicChallenge(payload);
    }

    throw const FormatException('Unsupported QR type.');
  }

  String? _payloadType(String rawPayload) {
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      return decoded['type'] as String?;
    } on FormatException {
      return null;
    }
  }

  Future<CheckInScanResult> processDynamicChallenge(
    QrChallengePayload payload,
  ) async {
    final business = await _ref.read(businessProfileControllerProvider.future);
    if (business == null) {
      return const CheckInScanResult(
        isValid: false,
        message: 'Business profile is not configured.',
      );
    }

    final isValidChallenge = await _ref
        .read(qrServiceProvider)
        .verifyDynamicChallenge(payload);
    if (!isValidChallenge) {
      await _saveDynamicEvent(payload, business.businessId, 'invalid QR');
      _ref.invalidate(businessCheckInsProvider(business.businessId));
      return const CheckInScanResult(isValid: false, message: 'invalid QR');
    }

    final result = await _ref.read(appDatabaseProvider).transaction(() async {
      if (await _isReplay(payload, business.businessId)) {
        await _saveDynamicEvent(payload, business.businessId, 'reused QR');
        return const CheckInScanResult(isValid: false, message: 'reused QR');
      }

      final cardRepository = _ref.read(cardRepositoryProvider);
      final subscription = await cardRepository.getSubscriptionCard(
        payload.cardId,
      );
      final invalidReason = _invalidReason(subscription, business.businessId);
      if (invalidReason == null) {
        final validSubscription = subscription!;
        if (_isWalletMismatch(validSubscription.linkedWalletId, payload)) {
          await _saveDynamicEvent(
            payload,
            business.businessId,
            'wallet mismatch',
          );
          return CheckInScanResult(
            isValid: false,
            message: 'wallet mismatch',
            subscription: validSubscription,
          );
        }

        await _saveDynamicEvent(payload, business.businessId, 'valid');
        if (validSubscription.remainingUses != null) {
          await cardRepository.saveSubscriptionCard(
            SubscriptionCard(
              businessId: validSubscription.businessId,
              cardId: validSubscription.cardId,
              customerId: validSubscription.customerId,
              name: validSubscription.name,
              createdAt: validSubscription.createdAt,
              status: validSubscription.status,
              subscriptionType: validSubscription.subscriptionType,
              startsAt: validSubscription.startsAt,
              expiresAt: validSubscription.expiresAt,
              notes: validSubscription.notes,
              validUntil: validSubscription.validUntil,
              remainingUses: validSubscription.remainingUses! - 1,
              linkedWalletId:
                  validSubscription.linkedWalletId ?? payload.walletId,
              dynamicChallenge: payload.dynamicChallenge,
              challengeTimestamp: payload.timestamp,
              challengeSignature: payload.signature,
            ),
          );
          _ref.invalidate(
            customerSubscriptionsProvider(validSubscription.customerId),
          );
          _ref.invalidate(subscriptionByIdProvider(validSubscription.cardId));
        }
        await recordCustomerVisit(_ref, validSubscription.customerId);
        return CheckInScanResult(
          isValid: true,
          message: 'Validated successfully',
          subscription: validSubscription,
        );
      }

      final loyaltyCard = await cardRepository.getLoyaltyCard(payload.cardId);
      final loyaltyInvalidReason = _invalidLoyaltyReason(
        loyaltyCard,
        business.businessId,
      );
      if (loyaltyInvalidReason != null) {
        final result = loyaltyCard == null
            ? invalidReason
            : loyaltyInvalidReason;
        await _saveDynamicEvent(payload, business.businessId, result);
        return CheckInScanResult(
          isValid: false,
          message: result,
          subscription: subscription,
        );
      }

      final validLoyaltyCard = loyaltyCard!;
      if (_isWalletMismatch(validLoyaltyCard.linkedWalletId, payload)) {
        await _saveDynamicEvent(
          payload,
          business.businessId,
          'wallet mismatch',
        );
        return const CheckInScanResult(
          isValid: false,
          message: 'wallet mismatch',
        );
      }

      final updatedProgress = advanceLoyaltyProgress(
        validLoyaltyCard,
        payload.timestamp,
      );
      await _saveDynamicEvent(payload, business.businessId, 'valid');
      await cardRepository.saveLoyaltyCard(
        validLoyaltyCard.copyWith(
          currentStamps: updatedProgress.value,
          challengeStartedAt: updatedProgress.challengeStartedAt,
          linkedWalletId: validLoyaltyCard.linkedWalletId ?? payload.walletId,
          dynamicChallenge: payload.dynamicChallenge,
          challengeTimestamp: payload.timestamp,
          challengeSignature: payload.signature,
          isBonusPending:
              updatedProgress.outcome ==
              LoyaltyProgressOutcome.thresholdReached,
          isCompleted:
              updatedProgress.outcome == LoyaltyProgressOutcome.bonusConsumed
              ? true
              : validLoyaltyCard.isCompleted,
        ),
      );
      _ref.invalidate(
        businessLoyaltyCardsProvider(validLoyaltyCard.businessId),
      );
      _ref.invalidate(
        customerLoyaltyCardsProvider(validLoyaltyCard.customerId),
      );
      _ref.invalidate(loyaltyCardByIdProvider(validLoyaltyCard.cardId));
      await recordCustomerVisit(_ref, validLoyaltyCard.customerId);
      if (updatedProgress.outcome == LoyaltyProgressOutcome.bonusConsumed) {
        await recordCustomerRewardEarned(_ref, validLoyaltyCard.customerId);
      }

      return CheckInScanResult(
        isValid: true,
        message: switch (updatedProgress.outcome) {
          LoyaltyProgressOutcome.thresholdReached => 'threshold_reached',
          LoyaltyProgressOutcome.bonusConsumed => 'bonus_entry',
          LoyaltyProgressOutcome.normal => 'Validated successfully',
        },
      );
    });

    _ref.invalidate(businessCheckInsProvider(business.businessId));
    return result;
  }

  Future<bool> _isReplay(QrChallengePayload payload, String businessId) async {
    return _ref
        .read(checkInRepositoryProvider)
        .hasValidCheckInForSignature(
          businessId: businessId,
          cardId: payload.cardId,
          signature: payload.signature,
        );
  }

  bool _isWalletMismatch(String? linkedWalletId, QrChallengePayload payload) {
    final linked = linkedWalletId?.trim();
    if (linked == null || linked.isEmpty) {
      return false;
    }
    return linked != payload.walletId.trim();
  }

  String? _invalidReason(SubscriptionCard? subscription, String businessId) {
    if (subscription == null || subscription.businessId != businessId) {
      return 'unknown';
    }
    if (subscription.status == CardStatus.suspended) {
      return 'suspended';
    }
    if (subscription.status == CardStatus.cancelled ||
        subscription.status == CardStatus.revoked) {
      return 'unknown';
    }
    if (subscription.effectiveStatus == CardStatus.expired) {
      return 'expired';
    }
    if (subscription.status != CardStatus.active) {
      return 'unknown';
    }
    if (subscription.remainingUses != null &&
        subscription.remainingUses! <= 0) {
      return 'no entries';
    }
    return null;
  }

  String? _invalidLoyaltyReason(LoyaltyCard? card, String businessId) {
    if (card == null || card.businessId != businessId) {
      return 'unknown';
    }
    if (card.isCompleted) {
      return 'card_completed';
    }
    if (card.status == CardStatus.suspended) {
      return 'suspended';
    }
    if (card.status == CardStatus.cancelled ||
        card.status == CardStatus.revoked) {
      return 'unknown';
    }
    final now = DateTime.now();
    if (card.validUntil != null && card.validUntil!.isBefore(now)) {
      return 'expired';
    }
    if (card.startsAt != null && card.startsAt!.isAfter(now)) {
      return 'not_active_yet';
    }
    if (card.status != CardStatus.active) {
      return 'unknown';
    }
    return null;
  }

  Future<void> _saveDynamicEvent(
    QrChallengePayload payload,
    String businessId,
    String result,
  ) async {
    final now = DateTime.now();
    await _ref
        .read(checkInRepositoryProvider)
        .saveCheckIn(
          CheckInEvent(
            eventId:
                'check-in-${now.microsecondsSinceEpoch}-${payload.signature.hashCode}-${result.hashCode}',
            businessId: businessId,
            cardId: payload.cardId,
            occurredAt: now,
            challengeTimestamp: payload.timestamp,
            signature: payload.signature,
            result: result,
          ),
        );
  }
}

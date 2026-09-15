import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/local_qr_service.dart';
import '../../data/repositories/drift_repositories.dart';
import '../../data/repositories/repository_interfaces.dart';
import '../../domain/entities/business_profile.dart';
import '../../domain/entities/check_in_event.dart';
import '../../domain/entities/customer_record.dart';
import '../../domain/entities/loyalty_card.dart';
import '../../domain/entities/subscription_card.dart';
import '../../domain/entities/subscription_import_payload.dart';
import '../../domain/services/loyalty_progress.dart';
import '../../domain/value_objects/qr_challenge_payload.dart';
import '../../domain/value_objects/card_status.dart';
import '../../domain/value_objects/loyalty_program_type.dart';
import 'app_settings_providers.dart';
import 'business_customers_providers.dart';
import 'business_profile_providers.dart';
import 'business_subscriptions_providers.dart';
import 'qr_providers.dart';

/// Which kind of QR/NFC payload a raw scan turned out to be, used by the
/// scanner UI to route to the right handler before doing any DB writes.
enum ScanPayloadKind { dynamicCheckIn, referralInvite, unknown }

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

/// Result of validating a referral invite before the business commits to
/// registering it (no DB writes happen until [BusinessCheckInController
/// .completeReferralRedemption] is called).
class ReferralRedemptionCheck {
  const ReferralRedemptionCheck({
    required this.isValid,
    required this.reason,
    this.payload,
    this.referrerCard,
  });

  final bool isValid;
  final String reason;
  final SubscriptionImportPayload? payload;
  final LoyaltyCard? referrerCard;
}

class BusinessCheckInController {
  const BusinessCheckInController(this._ref);

  final Ref _ref;

  ScanPayloadKind classifyRawPayload(String rawPayload) {
    final decoded = _tryDecodeJson(rawPayload);
    if (decoded == null) {
      return ScanPayloadKind.unknown;
    }
    final type = decoded['type'] as String?;
    if (type == LocalQrService.dynamicChallengeType) {
      return ScanPayloadKind.dynamicCheckIn;
    }
    if (type == LocalQrService.subscriptionImportType &&
        decoded['referrerCardId'] != null) {
      return ScanPayloadKind.referralInvite;
    }
    return ScanPayloadKind.unknown;
  }

  Future<CheckInScanResult> processRawPayload(String rawPayload) async {
    if (_payloadType(rawPayload) == LocalQrService.dynamicChallengeType) {
      final qrService = _ref.read(qrServiceProvider);
      final payload = qrService.decodeDynamicChallenge(rawPayload);
      return processDynamicChallenge(payload);
    }

    throw const FormatException('Unsupported QR type.');
  }

  /// Verifies a scanned referral invite without writing anything to the
  /// database yet — checks signature, that referrals are enabled here, that
  /// this exact invite hasn't already been redeemed, and looks up the
  /// referrer's card.
  Future<ReferralRedemptionCheck> prepareReferralRedemption(
    String rawPayload,
  ) async {
    final business = await _ref.read(businessProfileControllerProvider.future);
    if (business == null) {
      return const ReferralRedemptionCheck(isValid: false, reason: 'unknown');
    }

    final SubscriptionImportPayload payload;
    try {
      payload = _ref
          .read(qrServiceProvider)
          .decodeSubscriptionImportPayload(rawPayload);
    } on FormatException {
      return const ReferralRedemptionCheck(
        isValid: false,
        reason: 'invalid QR',
      );
    }

    return _validateReferral(payload, business);
  }

  /// Creates the friend's customer + loyalty card (with their welcome bonus
  /// already applied) and, if the referrer's card can still be found,
  /// grants them a reward too. Re-validates [payload] first, since time may
  /// have passed since [prepareReferralRedemption].
  Future<CheckInScanResult> completeReferralRedemption(
    SubscriptionImportPayload payload, {
    required String customerName,
    String? customerPhone,
  }) async {
    final business = await _ref.read(businessProfileControllerProvider.future);
    if (business == null) {
      return const CheckInScanResult(isValid: false, message: 'unknown');
    }

    final check = await _validateReferral(payload, business);
    if (!check.isValid) {
      return CheckInScanResult(isValid: false, message: check.reason);
    }

    final now = DateTime.now();
    final cardRepository = _ref.read(cardRepositoryProvider);
    final customerId = _newReferralCustomerId();
    final programType = _programTypeFromName(payload.programType);
    final rewardThreshold = payload.entriesTotal ?? 1;
    final entriesRemaining = payload.entriesRemaining ?? rewardThreshold;
    final currentStamps = (rewardThreshold - entriesRemaining).clamp(
      0,
      rewardThreshold,
    );

    await _ref
        .read(customerRepositoryProvider)
        .saveCustomer(
          CustomerRecord(
            customerId: customerId,
            businessId: business.businessId,
            displayName: customerName.trim(),
            createdAt: now,
            updatedAt: now,
            phone: customerPhone,
          ),
        );

    final newCard = LoyaltyCard(
      businessId: business.businessId,
      cardId: payload.subscriptionId,
      customerId: customerId,
      name: payload.cardTitle,
      createdAt: now,
      status: CardStatus.active,
      currentStamps: currentStamps,
      rewardThreshold: rewardThreshold,
      programType: programType,
      pointsPerScan: programType == LoyaltyProgramType.points
          ? (payload.scanValue ?? 10)
          : null,
      challengeWindowDays: programType == LoyaltyProgramType.visitChallenge
          ? (payload.challengeWindowDays ?? 30)
          : null,
      challengeStartedAt: programType == LoyaltyProgramType.visitChallenge
          ? now
          : null,
      startsAt: now,
    );
    await cardRepository.saveLoyaltyCard(newCard);
    _ref.invalidate(businessLoyaltyCardsProvider(business.businessId));
    _ref.invalidate(customerLoyaltyCardsProvider(customerId));
    _ref.invalidate(loyaltyCardByIdProvider(newCard.cardId));
    _ref.invalidate(businessCardCountProvider(business.businessId));
    _ref.invalidate(businessCustomersControllerProvider);

    final referrerCard = check.referrerCard;
    if (referrerCard == null) {
      return const CheckInScanResult(
        isValid: true,
        message: 'referral_registered_no_referrer',
      );
    }

    await _ref
        .read(businessSubscriptionActionsProvider)
        .grantBonusEntry(referrerCard.cardId);

    return const CheckInScanResult(
      isValid: true,
      message: 'referral_registered',
    );
  }

  Future<ReferralRedemptionCheck> _validateReferral(
    SubscriptionImportPayload payload,
    BusinessProfile business,
  ) async {
    if (!payload.isReferralInvite) {
      return const ReferralRedemptionCheck(
        isValid: false,
        reason: 'not_a_referral',
      );
    }
    if (payload.businessId != business.businessId) {
      return const ReferralRedemptionCheck(isValid: false, reason: 'unknown');
    }
    if (!business.referralProgramEnabled) {
      return ReferralRedemptionCheck(
        isValid: false,
        reason: 'referrals_disabled',
        payload: payload,
      );
    }

    final cardRepository = _ref.read(cardRepositoryProvider);
    final existingCard = await cardRepository.getLoyaltyCard(
      payload.subscriptionId,
    );
    if (existingCard != null) {
      return ReferralRedemptionCheck(
        isValid: false,
        reason: 'already_registered',
        payload: payload,
      );
    }

    LoyaltyCard? referrerCard;
    final referrerId = payload.referrerCardId;
    if (referrerId != null) {
      final candidate = await cardRepository.getLoyaltyCard(referrerId);
      if (candidate != null && candidate.businessId == business.businessId) {
        referrerCard = candidate;
      }
    }

    return ReferralRedemptionCheck(
      isValid: true,
      reason: 'ok',
      payload: payload,
      referrerCard: referrerCard,
    );
  }

  LoyaltyProgramType _programTypeFromName(String? name) {
    return LoyaltyProgramType.values.firstWhere(
      (value) => value.name == name,
      orElse: () => LoyaltyProgramType.stamps,
    );
  }

  String _newReferralCustomerId() {
    return 'customer-referral-${DateTime.now().microsecondsSinceEpoch}';
  }

  Map<String, Object?>? _tryDecodeJson(String rawPayload) {
    try {
      final decoded = jsonDecode(rawPayload);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  String? _payloadType(String rawPayload) {
    return _tryDecodeJson(rawPayload)?['type'] as String?;
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

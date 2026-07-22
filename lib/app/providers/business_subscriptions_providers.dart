import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/drift_repositories.dart';
import '../../data/repositories/repository_interfaces.dart';
import '../../domain/entities/license_status.dart';
import '../../domain/entities/subscription_card.dart';
import '../../domain/entities/loyalty_card.dart';
import '../../domain/value_objects/card_status.dart';
import '../../domain/value_objects/loyalty_program_type.dart';
import '../../domain/value_objects/subscription_type.dart';
import 'app_settings_providers.dart';
import 'license_providers.dart';

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return DriftCardRepository(ref.watch(appDatabaseProvider));
});

final customerSubscriptionsProvider =
    FutureProvider.family<List<SubscriptionCard>, String>((ref, customerId) {
      return ref
          .watch(cardRepositoryProvider)
          .listSubscriptionCardsForCustomer(customerId);
    });

final subscriptionByIdProvider =
    FutureProvider.family<SubscriptionCard?, String>((ref, subscriptionId) {
      return ref
          .watch(cardRepositoryProvider)
          .getSubscriptionCard(subscriptionId);
    });

final businessSubscriptionCardsProvider =
    FutureProvider.family<List<SubscriptionCard>, String>((ref, businessId) {
      return ref
          .watch(cardRepositoryProvider)
          .listSubscriptionCards(businessId);
    });

final businessLoyaltyCardsProvider =
    FutureProvider.family<List<LoyaltyCard>, String>((ref, businessId) {
      return ref.watch(cardRepositoryProvider).listLoyaltyCards(businessId);
    });

final businessCardCountProvider = FutureProvider.family<int, String>((
  ref,
  businessId,
) async {
  final repository = ref.watch(cardRepositoryProvider);
  final subscriptions = await repository.listSubscriptionCards(businessId);
  final loyaltyCards = await repository.listLoyaltyCards(businessId);
  return subscriptions.length + loyaltyCards.length;
});

final loyaltyCardByIdProvider = FutureProvider.family<LoyaltyCard?, String>((
  ref,
  loyaltyCardId,
) {
  return ref.watch(cardRepositoryProvider).getLoyaltyCard(loyaltyCardId);
});

final customerLoyaltyCardsProvider =
    FutureProvider.family<List<LoyaltyCard>, String>((ref, customerId) {
      return ref
          .watch(cardRepositoryProvider)
          .listLoyaltyCardsForCustomer(customerId);
    });

final businessSubscriptionActionsProvider =
    Provider<BusinessSubscriptionActions>((ref) {
      return BusinessSubscriptionActions(ref);
    });

class BusinessSubscriptionActions {
  const BusinessSubscriptionActions(this._ref);

  final Ref _ref;

  Future<String?> createSubscription({
    required String businessId,
    required String customerId,
    required SubscriptionType type,
    required String name,
    required DateTime startsAt,
    required DateTime expiresAt,
    int? remainingUses,
    String? notes,
  }) async {
    final license = await _ensureCanCreateCard(businessId);
    final repository = _ref.read(cardRepositoryProvider);
    final subscription = SubscriptionCard(
      businessId: businessId,
      cardId: _newSubscriptionId(),
      customerId: customerId,
      name: name.trim(),
      createdAt: DateTime.now(),
      status: CardStatus.active,
      subscriptionType: type,
      startsAt: startsAt,
      expiresAt: expiresAt,
      validUntil: expiresAt,
      remainingUses: remainingUses,
      notes: _nullableText(notes),
    );

    await repository.saveSubscriptionCard(subscription);
    _ref.invalidate(customerSubscriptionsProvider(customerId));
    _ref.invalidate(businessSubscriptionCardsProvider(businessId));
    _ref.invalidate(businessCardCountProvider(businessId));
    return _expiryWarning(license);
  }

  Future<String?> createLoyaltyCard({
    required String businessId,
    required String customerId,
    required String name,
    required int rewardThreshold,
    LoyaltyProgramType programType = LoyaltyProgramType.stamps,
    int? pointsPerScan,
    int? challengeWindowDays,
  }) async {
    final license = await _ensureCanCreateCard(businessId);
    final repository = _ref.read(cardRepositoryProvider);
    final card = LoyaltyCard(
      businessId: businessId,
      cardId: _newLoyaltyId(),
      customerId: customerId,
      name: name.trim(),
      createdAt: DateTime.now(),
      status: CardStatus.active,
      currentStamps: 0,
      rewardThreshold: rewardThreshold,
      programType: programType,
      pointsPerScan: programType == LoyaltyProgramType.points
          ? pointsPerScan ?? 10
          : null,
      challengeWindowDays: programType == LoyaltyProgramType.visitChallenge
          ? challengeWindowDays ?? 30
          : null,
      challengeStartedAt: programType == LoyaltyProgramType.visitChallenge
          ? DateTime.now()
          : null,
    );

    await repository.saveLoyaltyCard(card);
    _ref.invalidate(businessLoyaltyCardsProvider(businessId));
    _ref.invalidate(customerLoyaltyCardsProvider(customerId));
    _ref.invalidate(loyaltyCardByIdProvider(card.cardId));
    _ref.invalidate(businessCardCountProvider(businessId));
    return _expiryWarning(license);
  }

  Future<LoyaltyCard?> addDeliveryStamp(String loyaltyCardId) async {
    final repository = _ref.read(cardRepositoryProvider);
    final card = await repository.getLoyaltyCard(loyaltyCardId);
    if (card == null || card.programType != LoyaltyProgramType.delivery) {
      return card;
    }
    if (card.isCompleted || card.currentStamps >= card.rewardThreshold) {
      return card;
    }

    final newStamps = card.currentStamps + 1;
    final updated = card.copyWith(
      currentStamps: newStamps,
      isBonusPending: newStamps >= card.rewardThreshold,
    );

    await repository.saveLoyaltyCard(updated);
    _ref.invalidate(businessLoyaltyCardsProvider(updated.businessId));
    _ref.invalidate(loyaltyCardByIdProvider(updated.cardId));
    return updated;
  }

  Future<LoyaltyCard?> redeemDeliveryReward(String loyaltyCardId) async {
    final repository = _ref.read(cardRepositoryProvider);
    final card = await repository.getLoyaltyCard(loyaltyCardId);
    if (card == null || card.programType != LoyaltyProgramType.delivery) {
      return card;
    }
    if (card.isCompleted || card.currentStamps < card.rewardThreshold) {
      return card;
    }

    final updated = card.copyWith(isBonusPending: false, isCompleted: true);

    await repository.saveLoyaltyCard(updated);
    _ref.invalidate(businessLoyaltyCardsProvider(updated.businessId));
    _ref.invalidate(loyaltyCardByIdProvider(updated.cardId));
    return updated;
  }

  Future<void> deleteLoyaltyCard(String loyaltyCardId) async {
    final repository = _ref.read(cardRepositoryProvider);
    final card = await repository.getLoyaltyCard(loyaltyCardId);
    await repository.deleteLoyaltyCard(loyaltyCardId);
    _ref.invalidate(loyaltyCardByIdProvider(loyaltyCardId));
    if (card != null) {
      _ref.invalidate(businessLoyaltyCardsProvider(card.businessId));
      _ref.invalidate(customerLoyaltyCardsProvider(card.customerId));
      _ref.invalidate(businessCardCountProvider(card.businessId));
    }
  }

  Future<void> deleteSubscription(String subscriptionId) async {
    final repository = _ref.read(cardRepositoryProvider);
    final subscription = await repository.getSubscriptionCard(subscriptionId);
    await repository.deleteSubscriptionCard(subscriptionId);
    _ref.invalidate(subscriptionByIdProvider(subscriptionId));
    if (subscription != null) {
      _ref.invalidate(
        businessSubscriptionCardsProvider(subscription.businessId),
      );
      _ref.invalidate(
        customerSubscriptionsProvider(subscription.customerId),
      );
      _ref.invalidate(businessCardCountProvider(subscription.businessId));
    }
  }

  Future<LicenseStatus?> _ensureCanCreateCard(String businessId) async {
    final count = await _ref.read(businessCardCountProvider(businessId).future);
    if (count < 10) {
      return null;
    }

    final license = await _ref.read(
      businessLicenseStatusProvider(businessId).future,
    );
    if (!license.isActive) {
      throw LicenseRequiredException(
        'Free limit reached. Insert the licensed USB-C stick to create more cards.',
      );
    }
    return license;
  }

  String? _expiryWarning(LicenseStatus? license) {
    if (license == null || !license.isExpiringSoon) return null;
    final days = license.daysUntilExpiry!;
    if (days <= 1) return 'License expires tomorrow! Renew to avoid interruptions.';
    return 'License expires in $days days. Renew to avoid interruptions.';
  }

  static String _newSubscriptionId() {
    return 'subscription-${DateTime.now().microsecondsSinceEpoch}';
  }

  static String _newLoyaltyId() {
    return 'loyalty-${DateTime.now().microsecondsSinceEpoch}';
  }

  static String? _nullableText(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

class LicenseRequiredException implements Exception {
  const LicenseRequiredException(this.message);

  final String message;

  @override
  String toString() => message;
}

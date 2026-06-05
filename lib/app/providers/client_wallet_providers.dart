import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/drift_repositories.dart';
import '../../data/repositories/repository_interfaces.dart';
import '../../domain/entities/subscription_import_payload.dart';
import '../../domain/entities/wallet_card.dart';
import '../../domain/value_objects/card_status.dart';
import 'app_settings_providers.dart';
import 'qr_providers.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return DriftWalletRepository(ref.watch(appDatabaseProvider));
});

final clientWalletIdProvider = FutureProvider<String>((ref) async {
  final repository = ref.watch(appSettingsRepositoryProvider);
  final existingWalletId = await repository.loadClientWalletId();
  if (existingWalletId != null) {
    return existingWalletId;
  }

  final walletId = _newClientWalletId();
  await repository.saveClientWalletId(walletId);
  return walletId;
});

final clientWalletCardsProvider = FutureProvider<List<WalletCard>>((ref) async {
  final walletId = await ref.watch(clientWalletIdProvider.future);
  return ref.watch(walletRepositoryProvider).listWalletCards(walletId);
});

final clientWalletCardProvider = FutureProvider.family<WalletCard?, String>((
  ref,
  walletCardId,
) {
  return ref.watch(walletRepositoryProvider).getWalletCard(walletCardId);
});

final clientWalletImportControllerProvider =
    Provider<ClientWalletImportController>((ref) {
      return ClientWalletImportController(ref);
    });

class ClientWalletImportController {
  const ClientWalletImportController(this._ref);

  final Ref _ref;

  SubscriptionImportPayload decode(String rawPayload) {
    return _ref
        .read(qrServiceProvider)
        .decodeSubscriptionImportPayload(rawPayload);
  }

  Future<WalletCard?> findExisting(SubscriptionImportPayload payload) async {
    final walletId = await _ref.read(clientWalletIdProvider.future);
    return _ref
        .read(walletRepositoryProvider)
        .getWalletCardByCardId(
          walletId: walletId,
          cardId: payload.subscriptionId,
        );
  }

  Future<WalletCard?> importPayload(
    SubscriptionImportPayload payload, {
    required bool updateExisting,
  }) async {
    final repository = _ref.read(walletRepositoryProvider);
    final walletId = await _ref.read(clientWalletIdProvider.future);
    final existing = await findExisting(payload);
    if (existing != null && !updateExisting) {
      return existing;
    }

    final walletCard = WalletCard(
      walletCardId: existing?.walletCardId ?? _newWalletCardId(),
      walletId: walletId,
      businessId: payload.businessId,
      cardId: payload.subscriptionId,
      cardType: payload.cardType,
      displayName: payload.cardTitle,
      createdAt: existing?.createdAt ?? DateTime.now(),
      status: _statusFromPayload(payload),
      businessName: payload.businessName,
      businessDomain: payload.businessDomain,
      businessSymbol: payload.businessSymbol,
      businessAccentColor: payload.businessAccentColor,
      entriesTotal: payload.entriesTotal,
      entriesRemaining: payload.entriesRemaining,
      scanValue: payload.scanValue,
      validUntil: payload.validUntil,
    );

    await repository.saveWalletCard(walletCard);
    _ref.invalidate(clientWalletCardsProvider);
    _ref.invalidate(clientWalletCardProvider(walletCard.walletCardId));
    return walletCard;
  }

  Future<void> deleteWalletCard(String walletCardId) async {
    await _ref.read(walletRepositoryProvider).deleteWalletCard(walletCardId);
    _ref.invalidate(clientWalletCardsProvider);
    _ref.invalidate(clientWalletCardProvider(walletCardId));
  }

  Future<WalletCard?> updateMyCard(String walletCardId) async {
    final repository = _ref.read(walletRepositoryProvider);
    final card = await repository.getWalletCard(walletCardId);
    if (card == null) {
      return null;
    }

    final remaining = card.entriesRemaining;
    if (remaining == null) {
      return card;
    }

    final scanValue = card.scanValue ?? 1;
    final updated = card.copyWith(
      entriesRemaining: (remaining - scanValue).clamp(0, remaining).toInt(),
      challengeTimestamp: DateTime.now(),
    );
    await repository.saveWalletCard(updated);
    _ref.invalidate(clientWalletCardsProvider);
    _ref.invalidate(clientWalletCardProvider(walletCardId));
    return updated;
  }

  static String _newWalletCardId() {
    return 'wallet-card-${DateTime.now().microsecondsSinceEpoch}';
  }

  static CardStatus _statusFromPayload(SubscriptionImportPayload payload) {
    return payload.validUntil.isBefore(DateTime.now())
        ? CardStatus.expired
        : CardStatus.active;
  }
}

String _newClientWalletId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return 'wallet-${base64UrlEncode(bytes).replaceAll('=', '')}';
}

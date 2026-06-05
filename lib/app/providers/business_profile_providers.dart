import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/drift_repositories.dart';
import '../../data/repositories/repository_interfaces.dart';
import '../../domain/entities/business_profile.dart';
import 'app_settings_providers.dart';

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return DriftBusinessRepository(ref.watch(appDatabaseProvider));
});

final businessProfileControllerProvider =
    AsyncNotifierProvider<BusinessProfileController, BusinessProfile?>(
      BusinessProfileController.new,
    );

class BusinessProfileController extends AsyncNotifier<BusinessProfile?> {
  @override
  Future<BusinessProfile?> build() {
    return ref.watch(businessRepositoryProvider).getActiveBusiness();
  }

  Future<void> saveProfile(BusinessProfile profile) async {
    final repository = ref.read(businessRepositoryProvider);
    final existing = await repository.getBusinessProfile(profile.businessId);
    final profileToSave = BusinessProfile(
      businessId: profile.businessId,
      displayName: profile.displayName,
      createdAt: profile.createdAt,
      activityDomain: profile.activityDomain,
      phone: profile.phone,
      email: profile.email,
      address: profile.address,
      cardAccentColor: profile.cardAccentColor,
      activitySymbol: profile.activitySymbol,
      localPublicKey: _localSigningKey(profile, existing),
    );
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.saveBusinessProfile(profileToSave);
      return repository.getBusinessProfile(profileToSave.businessId);
    });
  }

  String _localSigningKey(BusinessProfile profile, BusinessProfile? existing) {
    final current = profile.localPublicKey?.trim();
    if (current != null && current.isNotEmpty) {
      return current;
    }
    final previous = existing?.localPublicKey?.trim();
    if (previous != null && previous.isNotEmpty) {
      return previous;
    }
    return _newLocalSigningKey();
  }

  String _newLocalSigningKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}

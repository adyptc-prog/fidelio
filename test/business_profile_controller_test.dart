import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fidelio/app/providers/app_settings_providers.dart';
import 'package:fidelio/app/providers/business_profile_providers.dart';
import 'package:fidelio/data/local_db/app_database.dart';
import 'package:fidelio/domain/entities/business_profile.dart';

void main() {
  test(
    'business profile save generates and preserves a local signing key',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        businessProfileControllerProvider.notifier,
      );
      await controller.saveProfile(
        BusinessProfile(
          businessId: 'business-1',
          displayName: 'Coffee Shop',
          createdAt: DateTime.utc(2026, 5, 18),
        ),
      );

      final saved = await container.read(
        businessProfileControllerProvider.future,
      );
      expect(saved?.localPublicKey, isNotNull);
      expect(saved!.localPublicKey, isNotEmpty);

      await controller.saveProfile(
        BusinessProfile(
          businessId: 'business-1',
          displayName: 'Coffee Shop Updated',
          createdAt: DateTime.utc(2026, 5, 18),
        ),
      );

      final updated = await container.read(
        businessProfileControllerProvider.future,
      );
      expect(updated?.localPublicKey, saved.localPublicKey);
    },
  );
}

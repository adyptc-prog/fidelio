import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_db/app_database.dart';
import '../../data/repositories/drift_repositories.dart';
import '../../data/repositories/repository_interfaces.dart';
import '../../data/services/local_app_settings_service.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/services/app_settings_service.dart';
import '../../domain/value_objects/app_mode.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return DriftAppSettingsRepository(ref.watch(appDatabaseProvider));
});

final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  return LocalAppSettingsService(ref.watch(appSettingsRepositoryProvider));
});

final appSettingsControllerProvider =
    AsyncNotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

class AppSettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() {
    return ref.watch(appSettingsServiceProvider).loadSettings();
  }

  Future<void> selectMode(AppMode mode) async {
    final service = ref.read(appSettingsServiceProvider);
    final current = state.valueOrNull ?? const AppSettings(selectedMode: null);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await service.saveSelectedMode(mode);
      return current.copyWith(selectedMode: mode);
    });
  }

  Future<void> clearMode() async {
    final service = ref.read(appSettingsServiceProvider);
    final current = state.valueOrNull ?? const AppSettings(selectedMode: null);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await service.clearSelectedMode();
      return current.copyWith(clearSelectedMode: true);
    });
  }

  Future<void> setClientCardsViewMode(ClientCardsViewMode mode) async {
    final service = ref.read(appSettingsServiceProvider);
    final current = state.valueOrNull ?? const AppSettings(selectedMode: null);
    state = await AsyncValue.guard(() async {
      await service.saveClientCardsViewMode(mode);
      return current.copyWith(clientCardsViewMode: mode);
    });
  }

  Future<void> setBusinessClientsViewMode(BusinessClientsViewMode mode) async {
    final service = ref.read(appSettingsServiceProvider);
    final current = state.valueOrNull ?? const AppSettings(selectedMode: null);
    state = await AsyncValue.guard(() async {
      await service.saveBusinessClientsViewMode(mode);
      return current.copyWith(businessClientsViewMode: mode);
    });
  }

  Future<void> setZoomMode(AppZoomMode mode) async {
    final service = ref.read(appSettingsServiceProvider);
    final current = state.valueOrNull ?? const AppSettings(selectedMode: null);
    state = await AsyncValue.guard(() async {
      await service.saveZoomMode(mode);
      return current.copyWith(zoomMode: mode);
    });
  }

  Future<void> setDarkMode(bool enabled) async {
    final service = ref.read(appSettingsServiceProvider);
    final current = state.valueOrNull ?? const AppSettings(selectedMode: null);
    state = await AsyncValue.guard(() async {
      await service.saveDarkMode(enabled);
      return current.copyWith(darkMode: enabled);
    });
  }
}

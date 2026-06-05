import '../entities/app_settings.dart';
import '../value_objects/app_mode.dart';

abstract interface class AppSettingsService {
  Future<AppSettings> loadSettings();

  Future<void> saveSelectedMode(AppMode mode);

  Future<void> clearSelectedMode();

  Future<void> saveClientCardsViewMode(ClientCardsViewMode mode);

  Future<void> saveBusinessClientsViewMode(BusinessClientsViewMode mode);

  Future<void> saveZoomMode(AppZoomMode mode);

  Future<void> saveDarkMode(bool enabled);
}

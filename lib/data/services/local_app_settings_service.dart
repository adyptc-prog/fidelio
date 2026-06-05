import '../../domain/entities/app_settings.dart';
import '../../domain/services/app_settings_service.dart';
import '../../domain/value_objects/app_mode.dart';
import '../repositories/repository_interfaces.dart';

class LocalAppSettingsService implements AppSettingsService {
  const LocalAppSettingsService(this._repository);

  final AppSettingsRepository _repository;

  @override
  Future<AppSettings> loadSettings() {
    return _repository.loadSettings();
  }

  @override
  Future<void> saveSelectedMode(AppMode mode) {
    return _repository.saveSelectedMode(mode);
  }

  @override
  Future<void> clearSelectedMode() {
    return _repository.clearSelectedMode();
  }

  @override
  Future<void> saveClientCardsViewMode(ClientCardsViewMode mode) {
    return _repository.saveClientCardsViewMode(mode);
  }

  @override
  Future<void> saveBusinessClientsViewMode(BusinessClientsViewMode mode) {
    return _repository.saveBusinessClientsViewMode(mode);
  }

  @override
  Future<void> saveZoomMode(AppZoomMode mode) {
    return _repository.saveZoomMode(mode);
  }

  @override
  Future<void> saveDarkMode(bool enabled) {
    return _repository.saveDarkMode(enabled);
  }
}

import '../value_objects/app_mode.dart';

enum ClientCardsViewMode { grid, list }

enum BusinessClientsViewMode { grid, list }

enum AppZoomMode { normal, large }

class AppSettings {
  const AppSettings({
    required this.selectedMode,
    this.clientCardsViewMode = ClientCardsViewMode.list,
    this.businessClientsViewMode = BusinessClientsViewMode.list,
    this.zoomMode = AppZoomMode.normal,
    this.darkMode = false,
  });

  final AppMode? selectedMode;
  final ClientCardsViewMode clientCardsViewMode;
  final BusinessClientsViewMode businessClientsViewMode;
  final AppZoomMode zoomMode;
  final bool darkMode;

  bool get hasSelectedMode => selectedMode != null;

  AppSettings copyWith({
    AppMode? selectedMode,
    bool clearSelectedMode = false,
    ClientCardsViewMode? clientCardsViewMode,
    BusinessClientsViewMode? businessClientsViewMode,
    AppZoomMode? zoomMode,
    bool? darkMode,
  }) {
    return AppSettings(
      selectedMode: clearSelectedMode
          ? null
          : selectedMode ?? this.selectedMode,
      clientCardsViewMode: clientCardsViewMode ?? this.clientCardsViewMode,
      businessClientsViewMode:
          businessClientsViewMode ?? this.businessClientsViewMode,
      zoomMode: zoomMode ?? this.zoomMode,
      darkMode: darkMode ?? this.darkMode,
    );
  }
}

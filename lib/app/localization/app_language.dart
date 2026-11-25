import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'ro_strings.dart';

/// Limba interfeței: română sau engleză. Aleasă din Setări și salvată pe
/// telefon; până la prima alegere urmează limba telefonului.
class AppLanguage {
  AppLanguage._();

  static const supported = ['ro', 'en'];
  static const _fileName = 'app_language.txt';

  /// Limba curentă ('ro' sau 'en'). Interfața se reconstruiește la schimbare.
  static final ValueNotifier<String> current = ValueNotifier<String>('en');

  static bool get isRomanian => current.value == 'ro';

  /// Citește limba salvată; fără ea, limba telefonului (română → 'ro').
  static Future<void> load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final saved = (await file.readAsString()).trim();
        if (supported.contains(saved)) {
          current.value = saved;
          return;
        }
      }
    } catch (_) {
      // Fără acces la fișiere (ex. teste): rămâne limba telefonului.
    }
    current.value = defaultForPlatform();
  }

  static String defaultForPlatform() =>
      PlatformDispatcher.instance.locale.languageCode == 'ro' ? 'ro' : 'en';

  static Future<void> set(String language) async {
    if (!supported.contains(language)) return;
    current.value = language;
    try {
      final file = await _file();
      await file.writeAsString(language, flush: true);
    } catch (_) {}
  }

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }
}

/// Textul [en] în limba curentă: traducerea din [kRoStrings] în română,
/// altfel textul englezesc neschimbat.
String t(String en) => AppLanguage.isRomanian ? (kRoStrings[en] ?? en) : en;

/// Pentru texte cu valori inserate (`$nume`): ambele variante scrise direct.
String tr(String ro, String en) => AppLanguage.isRomanian ? ro : en;

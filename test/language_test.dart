import 'dart:io';

import 'package:fidelio/app/localization/app_language.dart';
import 'package:fidelio/app/localization/ro_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AppLanguage.current.value = 'en');

  test('t și tr urmează limba aleasă', () {
    AppLanguage.current.value = 'en';
    expect(t('Save'), 'Save');
    expect(tr('Salvează', 'Save'), 'Save');

    AppLanguage.current.value = 'ro';
    expect(t('Save'), 'Salvează');
    expect(t('Customers'), 'Clienți');
    expect(tr('Salvează', 'Save'), 'Salvează');
    // Un text fără traducere rămâne în engleză, fără excepție.
    expect(t('Some text without translation'), 'Some text without translation');
  });

  test('fiecare text t(...) din aplicație are traducere în română', () {
    final used = <String>{};
    final pattern = RegExp(r"(?<![A-Za-z_])t\('((?:[^'\\]|\\.)*)'\)");
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final m in pattern.allMatches(entity.readAsStringSync())) {
        used.add(m.group(1)!.replaceAll(r"\'", "'"));
      }
    }
    expect(used, isNotEmpty);
    final missing = used.where((s) => !kRoStrings.containsKey(s)).toList();
    expect(missing, isEmpty, reason: 'Fără traducere: $missing');
  });
}

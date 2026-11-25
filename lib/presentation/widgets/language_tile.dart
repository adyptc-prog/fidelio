import 'package:flutter/material.dart';

import '../../app/localization/app_language.dart';

/// Alegerea limbii aplicației (română / engleză), din Setări.
class LanguageTile extends StatelessWidget {
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.language),
                const SizedBox(width: 16),
                Text(
                  t('App language'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: AppLanguage.current,
              builder: (context, language, _) => SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ro', label: Text('Română')),
                  ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {language},
                onSelectionChanged: (selection) =>
                    AppLanguage.set(selection.first),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

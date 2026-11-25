import 'package:flutter/material.dart';

import '../../../presentation/layouts/section_shell.dart';
import '../../../presentation/widgets/placeholder_page.dart';
import 'package:fidelio/app/localization/app_language.dart';

class ClientManualCardsScreen extends StatelessWidget {
  const ClientManualCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionShell(
      title: t('Manual Cards'),
      child: PlaceholderPage(
        title: t('Manual Cards'),
        description:
            t('Manually entered cards will be enabled after the QR flows are finalized.'),
      ),
    );
  }
}

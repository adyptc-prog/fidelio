import 'package:flutter/material.dart';

import '../../../presentation/layouts/section_shell.dart';
import '../../../presentation/widgets/placeholder_page.dart';

class ClientManualCardsScreen extends StatelessWidget {
  const ClientManualCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SectionShell(
      title: 'Manual Cards',
      child: PlaceholderPage(
        title: 'Manual Cards',
        description:
            'Manually entered cards will be enabled after the QR flows are finalized.',
      ),
    );
  }
}

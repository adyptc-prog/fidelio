import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../presentation/layouts/section_shell.dart';
import 'package:fidelio/app/localization/app_language.dart';

/// Lets the client review and edit a message recommending Fidelio to a
/// business, then share it via the system share sheet or copy it (e.g. to
/// paste as a review).
class ClientRecommendScreen extends StatefulWidget {
  const ClientRecommendScreen({super.key});

  @override
  State<ClientRecommendScreen> createState() => _ClientRecommendScreenState();
}

class _ClientRecommendScreenState extends State<ClientRecommendScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: AppConstants.recommendationText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionShell(
      title: t('Recommend Fidelio'),
      child: ListView(
        children: [
          Text(
            t('Edit the message below, then share it or copy it to paste as a review.'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            minLines: 6,
            maxLines: 12,
            decoration: InputDecoration(
              labelText: t('Message'),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.share),
            label: Text(t('Share')),
            onPressed: () => _share(context),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: Text(t('Copy Text')),
            onPressed: () => _copy(context),
          ),
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    try {
      await SharePlus.instance.share(ShareParams(text: _controller.text));
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('Nu s-a putut trimite: $error', 'Could not share: $error'))));
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _controller.text));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t('Text copied — paste it wherever you like.')),
      ),
    );
  }
}

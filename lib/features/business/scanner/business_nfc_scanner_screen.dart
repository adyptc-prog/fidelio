import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/business_check_in_providers.dart';
import '../../../app/providers/nfc_access_providers.dart';
import '../../../app/providers/scan_feedback_providers.dart';
import '../../../presentation/layouts/section_shell.dart';
import 'package:fidelio/app/localization/app_language.dart';

class BusinessNfcScannerScreen extends ConsumerStatefulWidget {
  const BusinessNfcScannerScreen({super.key});

  @override
  ConsumerState<BusinessNfcScannerScreen> createState() =>
      _BusinessNfcScannerScreenState();
}

class _BusinessNfcScannerScreenState
    extends ConsumerState<BusinessNfcScannerScreen> {
  bool _isReading = false;
  CheckInScanResult? _lastResult;

  @override
  Widget build(BuildContext context) {
    return SectionShell(
      title: t('NFC Access'),
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.nfc, size: 72),
                  const SizedBox(height: 12),
                  Text(
                    t('Read the client phone by NFC. The same local validation used for Dynamic QR will be applied.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.nfc),
                    label: Text(_isReading ? t('Waiting for NFC...') : t('Read NFC')),
                    onPressed: _isReading ? null : _readNfc,
                  ),
                ],
              ),
            ),
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 12),
            _ScanResultCard(result: _lastResult!),
          ],
        ],
      ),
    );
  }

  Future<void> _readNfc() async {
    setState(() {
      _isReading = true;
      _lastResult = null;
    });

    try {
      final rawPayload = await ref.read(nfcAccessServiceProvider).readPayload();
      final result = await ref
          .read(businessCheckInControllerProvider)
          .processRawPayload(rawPayload);
      if (!mounted) {
        return;
      }
      setState(() => _lastResult = result);
      unawaited(
        ref.read(scanFeedbackControllerProvider).playForCheckInResult(result),
      );
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      final result = CheckInScanResult(isValid: false, message: error.message);
      setState(() => _lastResult = result);
      unawaited(
        ref.read(scanFeedbackControllerProvider).playForCheckInResult(result),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final result = CheckInScanResult(
        isValid: false,
        message: error.toString(),
      );
      setState(() => _lastResult = result);
      unawaited(
        ref.read(scanFeedbackControllerProvider).playForCheckInResult(result),
      );
    } finally {
      if (mounted) {
        setState(() => _isReading = false);
      }
    }
  }
}

class _ScanResultCard extends StatelessWidget {
  const _ScanResultCard({required this.result});

  final CheckInScanResult result;

  @override
  Widget build(BuildContext context) {
    final color = result.isValid
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    final presentation = _ScanResultPresentation.fromResult(result);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(presentation.icon, color: color, size: 42),
            const SizedBox(height: 8),
            Text(
              presentation.title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: color),
            ),
            const SizedBox(height: 6),
            Text(presentation.description, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ScanResultPresentation {
  const _ScanResultPresentation({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  factory _ScanResultPresentation.fromResult(CheckInScanResult result) {
    return switch (result.message) {
      'threshold_reached' => _ScanResultPresentation(
        title: t('All Entries Reached!'),
        description:
            t('All regular entries were used. The next entry will be the bonus one.'),
        icon: Icons.celebration,
      ),
      'bonus_entry' => _ScanResultPresentation(
        title: t('This Entry Is Bonus!'),
        description:
            t('Bonus entry redeemed. This card is now fully used; create a new card for further visits.'),
        icon: Icons.stars,
      ),
      'card_completed' => _ScanResultPresentation(
        title: t('Card Fully Used'),
        description:
            t('All entries, including the bonus, were already used. Create a new card for this client.'),
        icon: Icons.block,
      ),
      'invalid QR' => _ScanResultPresentation(
        title: t('Invalid or Expired NFC'),
        description: t('Ask the client to prepare a fresh NFC access code.'),
        icon: Icons.timer_off,
      ),
      'reused QR' => _ScanResultPresentation(
        title: t('NFC Already Used'),
        description: t('This access code was already accepted.'),
        icon: Icons.replay_circle_filled,
      ),
      'wallet mismatch' => _ScanResultPresentation(
        title: t('Different Client Wallet'),
        description:
            t('This card is already linked to another client phone. Ask the client to use the original phone wallet.'),
        icon: Icons.phonelink_lock,
      ),
      'expired' => _ScanResultPresentation(
        title: t('Membership Expired'),
        description: t('The card exists, but its validity period has passed.'),
        icon: Icons.event_busy,
      ),
      'not_active_yet' => _ScanResultPresentation(
        title: t('Card Not Active Yet'),
        description: t('This card becomes valid on a future date.'),
        icon: Icons.hourglass_top,
      ),
      'no entries' => _ScanResultPresentation(
        title: t('No Entries Available'),
        description: t('The membership has no remaining entries.'),
        icon: Icons.remove_circle,
      ),
      'suspended' => _ScanResultPresentation(
        title: t('Card Suspended'),
        description: t('The card is suspended and cannot be validated.'),
        icon: Icons.pause_circle,
      ),
      'unknown' => _ScanResultPresentation(
        title: t('Unknown Card'),
        description:
            t('The NFC data does not match an active membership for this business.'),
        icon: Icons.help,
      ),
      _ =>
        result.isValid
            ? _ScanResultPresentation(
                title: t('Access Validated'),
                description: t('Check-in recorded. The membership was updated.'),
                icon: Icons.check_circle,
              )
            : _ScanResultPresentation(
                title: t('NFC Rejected'),
                description: result.message,
                icon: Icons.error,
              ),
    };
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/business_check_in_providers.dart';
import '../../../app/providers/nfc_access_providers.dart';
import '../../../presentation/layouts/section_shell.dart';

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
      title: 'NFC Access',
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
                  const Text(
                    'Read the client phone by NFC. The same local validation used for Dynamic QR will be applied.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.nfc),
                    label: Text(_isReading ? 'Waiting for NFC...' : 'Read NFC'),
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
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      setState(
        () => _lastResult = CheckInScanResult(
          isValid: false,
          message: error.message,
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(
        () => _lastResult = CheckInScanResult(
          isValid: false,
          message: error.toString(),
        ),
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
    if (result.isValid) {
      return const _ScanResultPresentation(
        title: 'Access Validated',
        description: 'Check-in recorded. The membership was updated.',
        icon: Icons.check_circle,
      );
    }

    return switch (result.message) {
      'invalid QR' => const _ScanResultPresentation(
        title: 'Invalid or Expired NFC',
        description: 'Ask the client to prepare a fresh NFC access code.',
        icon: Icons.timer_off,
      ),
      'reused QR' => const _ScanResultPresentation(
        title: 'NFC Already Used',
        description: 'This access code was already accepted.',
        icon: Icons.replay_circle_filled,
      ),
      'wallet mismatch' => const _ScanResultPresentation(
        title: 'Different Client Wallet',
        description:
            'This card is already linked to another client phone. Ask the client to use the original phone wallet.',
        icon: Icons.phonelink_lock,
      ),
      'expired' => const _ScanResultPresentation(
        title: 'Membership Expired',
        description: 'The card exists, but its validity period has passed.',
        icon: Icons.event_busy,
      ),
      'no entries' => const _ScanResultPresentation(
        title: 'No Entries Available',
        description: 'The membership has no remaining entries.',
        icon: Icons.remove_circle,
      ),
      'suspended' => const _ScanResultPresentation(
        title: 'Card Suspended',
        description: 'The card is suspended and cannot be validated.',
        icon: Icons.pause_circle,
      ),
      'reward_earned' => const _ScanResultPresentation(
        title: 'Reward Earned!',
        description:
            'The loyalty threshold was reached. Progress has been reset.',
        icon: Icons.stars,
      ),
      'unknown' => const _ScanResultPresentation(
        title: 'Unknown Card',
        description:
            'The NFC data does not match an active membership for this business.',
        icon: Icons.help,
      ),
      _ => _ScanResultPresentation(
        title: 'NFC Rejected',
        description: result.message,
        icon: Icons.error,
      ),
    };
  }
}

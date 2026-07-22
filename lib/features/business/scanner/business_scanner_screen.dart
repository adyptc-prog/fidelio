import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/providers/business_check_in_providers.dart';
import '../../../presentation/layouts/section_shell.dart';

class BusinessScannerScreen extends ConsumerStatefulWidget {
  const BusinessScannerScreen({super.key});

  @override
  ConsumerState<BusinessScannerScreen> createState() =>
      _BusinessScannerScreenState();
}

class _BusinessScannerScreenState extends ConsumerState<BusinessScannerScreen> {
  final _scannerController = MobileScannerController();
  bool _handlingScan = false;
  CheckInScanResult? _lastResult;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionShell(
      title: 'Scan',
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 320,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: MobileScanner(
                        controller: _scannerController,
                        onDetect: _onDetect,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Scan the check-in QR shown by the client.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 12),
            _ScanResultCard(result: _lastResult!, onScanAgain: _restartScanner),
          ],
        ],
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handlingScan) {
      return;
    }

    final rawValue = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }

    _handlingScan = true;
    await _scannerController.stop();

    try {
      final result = await ref
          .read(businessCheckInControllerProvider)
          .processRawPayload(rawValue);
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
    } on Object {
      if (!mounted) {
        return;
      }
      setState(
        () => _lastResult = const CheckInScanResult(
          isValid: false,
          message: 'unknown',
        ),
      );
    }
  }

  Future<void> _restartScanner() async {
    setState(() => _lastResult = null);
    _handlingScan = false;
    await _scannerController.start();
  }
}

class _ScanResultCard extends StatelessWidget {
  const _ScanResultCard({required this.result, required this.onScanAgain});

  final CheckInScanResult result;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final presentation = _ScanResultPresentation.fromResult(result);
    final color = result.isValid
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;

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
            if (result.subscription != null) ...[
              const SizedBox(height: 12),
              Text(
                result.subscription!.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (result.subscription!.remainingUses != null)
                Text(
                  'Entries remaining before validation: ${result.subscription!.remainingUses}',
                  textAlign: TextAlign.center,
                ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Again'),
              onPressed: onScanAgain,
            ),
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
      'threshold_reached' => const _ScanResultPresentation(
        title: 'All Entries Reached!',
        description:
            'All regular entries were used. The next entry will be the bonus one.',
        icon: Icons.celebration,
      ),
      'bonus_entry' => const _ScanResultPresentation(
        title: 'This Entry Is Bonus!',
        description:
            'Bonus entry redeemed. This card is now fully used; create a new card for further visits.',
        icon: Icons.stars,
      ),
      'card_completed' => const _ScanResultPresentation(
        title: 'Card Fully Used',
        description:
            'All entries, including the bonus, were already used. Create a new card for this client.',
        icon: Icons.block,
      ),
      'invalid QR' => const _ScanResultPresentation(
        title: 'Invalid or Expired QR',
        description: 'Ask the client to generate a new code and scan again.',
        icon: Icons.timer_off,
      ),
      'reused QR' => const _ScanResultPresentation(
        title: 'QR Already Used',
        description:
            'This code was already accepted and can no longer be used.',
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
      'unknown' => const _ScanResultPresentation(
        title: 'Unknown Card',
        description:
            'The code does not match an active membership for this business.',
        icon: Icons.help,
      ),
      _ => result.isValid
          ? const _ScanResultPresentation(
              title: 'Access Validated',
              description: 'Check-in recorded. The membership was updated.',
              icon: Icons.check_circle,
            )
          : _ScanResultPresentation(
              title: 'Scan Rejected',
              description: result.message,
              icon: Icons.error,
            ),
    };
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/providers/business_check_in_providers.dart';
import '../../../app/providers/scan_feedback_providers.dart';
import '../../../presentation/layouts/section_shell.dart';
import 'package:fidelio/app/localization/app_language.dart';

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
      title: t('Scan'),
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
                  Text(
                    t('Scan the check-in QR shown by the client.'),
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
    unawaited(
      ref
          .read(scanFeedbackControllerProvider)
          .play(ScanFeedbackEvent.scanDetected),
    );

    final controller = ref.read(businessCheckInControllerProvider);
    if (controller.classifyRawPayload(rawValue) ==
        ScanPayloadKind.referralInvite) {
      await _handleReferralInvite(rawValue);
      return;
    }

    try {
      final result = await controller.processRawPayload(rawValue);
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
    } on Object {
      if (!mounted) {
        return;
      }
      const result = CheckInScanResult(isValid: false, message: 'unknown');
      setState(() => _lastResult = result);
      unawaited(
        ref.read(scanFeedbackControllerProvider).playForCheckInResult(result),
      );
    }
  }

  Future<void> _handleReferralInvite(String rawValue) async {
    final controller = ref.read(businessCheckInControllerProvider);
    final check = await controller.prepareReferralRedemption(rawValue);

    if (!check.isValid) {
      if (!mounted) {
        return;
      }
      final result = CheckInScanResult(isValid: false, message: check.reason);
      setState(() => _lastResult = result);
      unawaited(
        ref.read(scanFeedbackControllerProvider).playForCheckInResult(result),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    final info = await _showReferralNameDialog(context);
    if (info == null) {
      if (mounted) {
        await _restartScanner();
      }
      return;
    }

    final result = await controller.completeReferralRedemption(
      check.payload!,
      customerName: info.name,
      customerPhone: info.phone,
    );
    if (!mounted) {
      return;
    }
    setState(() => _lastResult = result);
    unawaited(
      ref.read(scanFeedbackControllerProvider).playForCheckInResult(result),
    );
  }

  Future<_ReferralCustomerInfo?> _showReferralNameDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    return showDialog<_ReferralCustomerInfo>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(t('New Referred Customer')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('Cardul a fost trimis de un client existent. Introdu datele '
                  'clientului nou ca să-i înregistrezi cardul.',
                  'This card was shared by an existing customer. Enter the new '
                  "customer's details to register their card."),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: t('Customer Name'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: t('Phone optional'),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              Navigator.of(context).pop(
                _ReferralCustomerInfo(
                  name: name.isEmpty ? t('New Customer') : name,
                  phone: phoneController.text.trim().isEmpty
                      ? null
                      : phoneController.text.trim(),
                ),
              );
            },
            child: Text(t('Register')),
          ),
        ],
      ),
    );
  }

  Future<void> _restartScanner() async {
    setState(() => _lastResult = null);
    _handlingScan = false;
    await _scannerController.start();
  }
}

class _ReferralCustomerInfo {
  const _ReferralCustomerInfo({required this.name, this.phone});

  final String name;
  final String? phone;
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
                  tr('Intrări rămase înainte de validare: ${result.subscription!.remainingUses}', 'Entries remaining before validation: ${result.subscription!.remainingUses}'),
                  textAlign: TextAlign.center,
                ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(t('Scan Again')),
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
        title: t('Invalid or Expired QR'),
        description: t('Ask the client to generate a new code and scan again.'),
        icon: Icons.timer_off,
      ),
      'reused QR' => _ScanResultPresentation(
        title: t('QR Already Used'),
        description:
            t('This code was already accepted and can no longer be used.'),
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
            t('The code does not match an active membership for this business.'),
        icon: Icons.help,
      ),
      'referral_registered' => _ScanResultPresentation(
        title: t('Referral Registered!'),
        description: tr(
            'Cardul nou a fost creat cu un bonus de bun venit, iar cel care '
            'l-a recomandat a primit o recompensă pe cardul lui.',
            'The new card was created with a welcome bonus, and the '
            'referrer received a reward on their card.'),
        icon: Icons.celebration,
      ),
      'referral_registered_no_referrer' => _ScanResultPresentation(
        title: t('Card Registered'),
        description: tr(
            'Cardul nou a fost creat cu un bonus de bun venit. Cardul celui '
            'care l-a recomandat nu mai există, deci nu s-a acordat recompensa.',
            'The new card was created with a welcome bonus. The referrer\'s '
            'card could no longer be found, so no reward was granted.'),
        icon: Icons.person_add_alt_1,
      ),
      'referrals_disabled' => _ScanResultPresentation(
        title: t('Referrals Disabled'),
        description: tr(
            'Codul e o invitație de recomandare, dar programul de recomandări '
            'e oprit. Pornește-l din Setări ca să-l accepți.',
            'This code is a referral invite, but the referral program is '
            'turned off. Enable it in Settings to accept it.'),
        icon: Icons.toggle_off,
      ),
      'already_registered' => _ScanResultPresentation(
        title: t('Already Registered'),
        description: t('This referral code was already used to register a card.'),
        icon: Icons.replay_circle_filled,
      ),
      'not_a_referral' => _ScanResultPresentation(
        title: t('Not a Check-In Code'),
        description: tr(
            'Pare un card care trebuie importat de client, nu scanat de '
            'afacere.',
            'This looks like a card meant to be imported by a client, not '
            'scanned by the business.'),
        icon: Icons.error_outline,
      ),
      _ =>
        result.isValid
            ? _ScanResultPresentation(
                title: t('Access Validated'),
                description: t('Check-in recorded. The membership was updated.'),
                icon: Icons.check_circle,
              )
            : _ScanResultPresentation(
                title: t('Scan Rejected'),
                description: result.message,
                icon: Icons.error,
              ),
    };
  }
}

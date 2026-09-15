import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/providers/client_wallet_providers.dart';
import '../../../app/providers/qr_providers.dart';
import '../../../domain/entities/wallet_card.dart';
import '../../../presentation/layouts/section_shell.dart';

/// Shown for a referral-received card that hasn't been scanned in by the
/// business yet. Displays the same signed invite so the business can
/// register the card on the friend's first visit.
class ClientReferralActivationScreen extends ConsumerStatefulWidget {
  const ClientReferralActivationScreen({required this.walletCardId, super.key});

  final String walletCardId;

  @override
  ConsumerState<ClientReferralActivationScreen> createState() =>
      _ClientReferralActivationScreenState();
}

class _ClientReferralActivationScreenState
    extends ConsumerState<ClientReferralActivationScreen> {
  String? _qrData;
  String? _errorMessage;
  bool _isConfirming = false;

  @override
  Widget build(BuildContext context) {
    final card = ref.watch(clientWalletCardProvider(widget.walletCardId));

    return SectionShell(
      title: 'Activate Card',
      child: card.when(
        data: (card) {
          if (card == null) {
            return const Center(child: Text('Card not found.'));
          }
          if (_qrData == null && _errorMessage == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _generate(card);
              }
            });
          }
          return _ActivationContent(
            card: card,
            qrData: _qrData,
            errorMessage: _errorMessage,
            isConfirming: _isConfirming,
            onRetry: () => _generate(card),
            onConfirm: _isConfirming ? null : () => _confirm(card),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Could not load card: $error')),
      ),
    );
  }

  void _generate(WalletCard card) {
    try {
      final qrService = ref.read(qrServiceProvider);
      final payload = qrService.createReferralActivationPayload(
        referredCard: card,
      );
      final rawPayload = qrService.encodeSubscriptionImportPayload(payload);
      if (!mounted) {
        return;
      }
      setState(() {
        _qrData = rawPayload;
        _errorMessage = null;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _qrData = null;
        _errorMessage = 'Could not generate the activation code: $error';
      });
    }
  }

  Future<void> _confirm(WalletCard card) async {
    setState(() => _isConfirming = true);
    try {
      await ref
          .read(clientWalletImportControllerProvider)
          .confirmReferralActivation(card.walletCardId);
      if (mounted) {
        context.pop();
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update card: $error')));
    }
  }
}

class _ActivationContent extends StatelessWidget {
  const _ActivationContent({
    required this.card,
    required this.qrData,
    required this.errorMessage,
    required this.isConfirming,
    required this.onRetry,
    required this.onConfirm,
  });

  final WalletCard card;
  final String? qrData;
  final String? errorMessage;
  final bool isConfirming;
  final VoidCallback onRetry;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  card.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  card.businessName ?? card.businessId,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'This card was shared by a friend. Show this code to the '
              'business on your first visit so they can activate it.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (errorMessage != null) ...[
                  Text(errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                    onPressed: onRetry,
                  ),
                ] else if (qrData == null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  ),
                ] else ...[
                  const Text(
                    'Show this code for scanning.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  QrImageView(
                    data: qrData!,
                    version: QrVersions.auto,
                    size: 280,
                    backgroundColor: Colors.white,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.done_all),
          label: Text(isConfirming ? 'Updating...' : 'I showed this — Done'),
          onPressed: onConfirm,
        ),
      ],
    );
  }
}

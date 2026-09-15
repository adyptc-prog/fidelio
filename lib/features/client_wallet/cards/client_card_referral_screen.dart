import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/providers/client_wallet_providers.dart';
import '../../../app/providers/qr_providers.dart';
import '../../../domain/entities/wallet_card.dart';
import '../../../presentation/layouts/section_shell.dart';

/// Lets a customer share their loyalty card with a friend who's physically
/// present. Generates a one-time referral QR: the friend's imported card
/// starts with a welcome bonus, and once they visit the business the
/// referrer gets a reward too.
class ClientCardReferralScreen extends ConsumerStatefulWidget {
  const ClientCardReferralScreen({required this.walletCardId, super.key});

  final String walletCardId;

  @override
  ConsumerState<ClientCardReferralScreen> createState() =>
      _ClientCardReferralScreenState();
}

class _ClientCardReferralScreenState
    extends ConsumerState<ClientCardReferralScreen> {
  String? _qrData;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final card = ref.watch(clientWalletCardProvider(widget.walletCardId));

    return SectionShell(
      title: 'Refer a Friend',
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
          return _ReferralContent(
            card: card,
            qrData: _qrData,
            errorMessage: _errorMessage,
            onRetry: () => _generate(card),
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
      final payload = qrService.createReferralInvitePayload(sourceCard: card);
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
        _errorMessage = 'Could not generate the referral code: $error';
      });
    }
  }
}

class _ReferralContent extends StatelessWidget {
  const _ReferralContent({
    required this.card,
    required this.qrData,
    required this.errorMessage,
    required this.onRetry,
  });

  final WalletCard card;
  final String? qrData;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final businessName = card.businessName ?? card.businessId;

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
                  businessName,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ],
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
                    'Show this code to your friend.',
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How it works',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Your friend opens Fidelio → Import Card and scans this code.\n'
                  '2. Their new card starts with a welcome bonus already on it.\n'
                  '3. Once they visit $businessName and their card is registered, '
                  'you receive a reward on your card too.\n\n'
                  'This code is a one-time invite for a single friend.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

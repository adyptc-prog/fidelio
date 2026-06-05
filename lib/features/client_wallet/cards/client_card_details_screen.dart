import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/client_wallet_providers.dart';
import '../../../core/constants/route_names.dart';
import '../../../domain/entities/wallet_card.dart';
import '../../../domain/value_objects/card_status.dart';
import '../../../presentation/layouts/section_shell.dart';

class ClientCardDetailsScreen extends ConsumerWidget {
  const ClientCardDetailsScreen({required this.walletCardId, super.key});

  final String walletCardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(clientWalletCardProvider(walletCardId));

    return SectionShell(
      title: 'Card Details',
      child: card.when(
        data: (card) {
          if (card == null) {
            return const Center(child: Text('Card not found.'));
          }
          return _CardDetails(
            card: card,
            onShowQr: card.status == CardStatus.active
                ? () => context.push(_cardRoute(RouteNames.clientCardQrAccess))
                : null,
            onWriteNfc: card.status == CardStatus.active
                ? () => context.push(_cardRoute(RouteNames.clientCardNfcAccess))
                : null,
            onDelete: () => _deleteCard(context, ref, card),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Could not load card details: $error')),
      ),
    );
  }

  String _cardRoute(String route) {
    return route.replaceFirst(':walletCardId', walletCardId);
  }

  Future<void> _deleteCard(
    BuildContext context,
    WidgetRef ref,
    WalletCard card,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete card?'),
        content: const Text(
          'The card will be removed from the client local wallet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    await ref
        .read(clientWalletImportControllerProvider)
        .deleteWalletCard(card.walletCardId);
    if (context.mounted) {
      context.pop();
    }
  }
}

class _CardDetails extends StatelessWidget {
  const _CardDetails({
    required this.card,
    required this.onShowQr,
    required this.onWriteNfc,
    required this.onDelete,
  });

  final WalletCard card;
  final VoidCallback? onShowQr;
  final VoidCallback? onWriteNfc;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.businessName ?? card.businessId,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if ((card.businessDomain ?? '').trim().isNotEmpty)
                  Text(
                    card.businessDomain!.trim(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                const SizedBox(height: 6),
                Text(
                  card.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _InfoLine(label: 'Status', value: _statusLabel(card.status)),
                _InfoLine(label: 'Valid', value: _dateOrDash(card.validUntil)),
                if (card.entriesRemaining != null)
                  _InfoLine(
                    label: card.cardType == 'loyalty' ? 'Progress' : 'Entries',
                    value: _entriesLabel(card),
                  ),
                _InfoLine(label: 'Card ID', value: card.cardId),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.qr_code_2),
          label: const Text('Generate QR Code'),
          onPressed: onShowQr,
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.nfc),
          label: const Text('NFC'),
          onPressed: onWriteNfc,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete Card'),
          onPressed: onDelete,
        ),
        if (card.status != CardStatus.active) ...[
          const SizedBox(height: 8),
          const Text(
            'Access is available only for active cards.',
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _dateOrDash(DateTime? value) {
  if (value == null) {
    return '-';
  }
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _statusLabel(CardStatus status) {
  return switch (status) {
    CardStatus.active => 'active',
    CardStatus.expired => 'expired',
    CardStatus.suspended => 'suspended',
    CardStatus.cancelled => 'cancelled',
    CardStatus.draft => 'draft',
    CardStatus.revoked => 'revoked',
  };
}

String _entriesLabel(WalletCard card) {
  if (card.entriesRemaining == null) {
    return '-';
  }
  if (card.entriesTotal == null) {
    return card.entriesRemaining.toString();
  }
  if (card.cardType == 'loyalty') {
    final current = card.entriesTotal! - card.entriesRemaining!;
    return '$current/${card.entriesTotal}';
  }
  return '${card.entriesRemaining}/${card.entriesTotal}';
}

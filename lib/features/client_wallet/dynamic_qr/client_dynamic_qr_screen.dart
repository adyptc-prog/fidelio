import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/providers/client_wallet_providers.dart';
import '../../../app/providers/nfc_access_providers.dart';
import '../../../app/providers/qr_providers.dart';
import '../../../domain/entities/wallet_card.dart';
import '../../../domain/value_objects/card_status.dart';
import '../../../presentation/layouts/section_shell.dart';

class ClientDynamicQrScreen extends ConsumerStatefulWidget {
  const ClientDynamicQrScreen({super.key});

  @override
  ConsumerState<ClientDynamicQrScreen> createState() =>
      _ClientDynamicQrScreenState();
}

class _ClientDynamicQrScreenState extends ConsumerState<ClientDynamicQrScreen> {
  String? _selectedWalletCardId;
  String? _qrData;
  DateTime? _issuedAt;
  bool _isGenerating = false;
  bool _isWritingNfc = false;
  String? _errorMessage;
  String? _nfcMessage;

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(clientWalletCardsProvider);

    return SectionShell(
      title: 'Dynamic QR/NFC',
      child: cards.when(
        data: _buildLoaded,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Could not load wallet: $error')),
      ),
    );
  }

  Widget _buildLoaded(List<WalletCard> cards) {
    if (cards.isEmpty) {
      return const Center(
        child: Text(
          'There are no cards in the wallet. Import a card before generating a QR.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final selectedCard = _selectedCard(cards);
    final canGenerate = selectedCard.status == CardStatus.active;
    if (_qrData == null && canGenerate && !_isGenerating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _generateQr(selectedCard);
        }
      });
    }

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Card', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedCard.walletCardId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: cards
                      .map(
                        (card) => DropdownMenuItem(
                          value: card.walletCardId,
                          child: Text(_cardLabel(card)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedWalletCardId = value;
                      _qrData = null;
                      _issuedAt = null;
                      _errorMessage = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _InfoLine(label: 'Status', value: _statusLabel(selectedCard)),
                _InfoLine(
                  label: 'Business',
                  value: selectedCard.businessName ?? selectedCard.businessId,
                ),
                _InfoLine(label: 'Card ID', value: selectedCard.cardId),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Generate Dynamic QR'),
          onPressed: canGenerate && !_isGenerating
              ? () => _generateQr(selectedCard)
              : null,
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.nfc),
          label: Text(
            _isWritingNfc ? 'Preparing NFC...' : 'Share Dynamic NFC',
          ),
          onPressed: canGenerate && !_isGenerating && !_isWritingNfc
              ? () => _writeDynamicNfc(selectedCard)
              : null,
        ),
        if (_nfcMessage != null) ...[
          const SizedBox(height: 8),
          Text(_nfcMessage!, textAlign: TextAlign.center),
        ],
        const SizedBox(height: 16),
        if (!canGenerate)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'QR is available only for active cards.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else if (_isGenerating)
          const Center(child: CircularProgressIndicator())
        else if (_errorMessage != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_errorMessage!, textAlign: TextAlign.center),
            ),
          )
        else if (_qrData != null)
          _QrPreview(qrData: _qrData!, issuedAt: _issuedAt),
      ],
    );
  }

  WalletCard _selectedCard(List<WalletCard> cards) {
    final selectedId = _selectedWalletCardId;
    if (selectedId != null) {
      for (final card in cards) {
        if (card.walletCardId == selectedId) {
          return card;
        }
      }
    }

    final activeCards = cards.where((card) => card.status == CardStatus.active);
    return activeCards.isEmpty ? cards.first : activeCards.first;
  }

  Future<void> _generateQr(WalletCard card) async {
    setState(() {
      _selectedWalletCardId = card.walletCardId;
      _isGenerating = true;
      _errorMessage = null;
      _nfcMessage = null;
    });

    try {
      final qrService = ref.read(qrServiceProvider);
      final payload = await qrService.createDynamicChallenge(
        walletId: card.walletId,
        cardId: card.cardId,
      );
      final qrData = qrService.encodeDynamicChallenge(payload);
      if (!mounted) {
        return;
      }
      setState(() {
        _qrData = qrData;
        _issuedAt = payload.timestamp;
        _isGenerating = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _qrData = null;
        _issuedAt = null;
        _isGenerating = false;
        _errorMessage = 'Could not generate QR: $error';
      });
    }
  }

  Future<void> _writeDynamicNfc(WalletCard card) async {
    setState(() {
      _selectedWalletCardId = card.walletCardId;
      _isWritingNfc = true;
      _errorMessage = null;
      _nfcMessage = null;
    });

    try {
      final qrService = ref.read(qrServiceProvider);
      final payload = await qrService.createDynamicChallenge(
        walletId: card.walletId,
        cardId: card.cardId,
      );
      final rawPayload = qrService.encodeDynamicChallenge(payload);
      await ref.read(nfcAccessServiceProvider).writePayload(rawPayload);
      if (!mounted) {
        return;
      }
      setState(() {
        _issuedAt = payload.timestamp;
        _nfcMessage =
            'Dynamic NFC access is ready at ${_timeLabel(payload.timestamp)}. Hold this phone near the business tablet.';
        _isWritingNfc = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isWritingNfc = false;
        _nfcMessage = 'Could not prepare NFC: $error';
      });
    }
  }
}

class _QrPreview extends StatelessWidget {
  const _QrPreview({required this.qrData, required this.issuedAt});

  final String qrData;
  final DateTime? issuedAt;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Show this code for scanning.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 280,
              backgroundColor: Colors.white,
            ),
            if (issuedAt != null) ...[
              const SizedBox(height: 12),
              Text(
                'Generated at ${_timeLabel(issuedAt!)}',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
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

String _cardLabel(WalletCard card) {
  final businessName = card.businessName ?? card.businessId;
  return '$businessName - ${card.displayName}';
}

String _statusLabel(WalletCard card) {
  return switch (card.status) {
    CardStatus.active => 'active',
    CardStatus.expired => 'expired',
    CardStatus.suspended => 'suspended',
    CardStatus.cancelled => 'cancelled',
    CardStatus.draft => 'draft',
    CardStatus.revoked => 'revoked',
  };
}

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final second = local.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

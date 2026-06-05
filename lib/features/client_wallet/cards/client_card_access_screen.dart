import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/providers/client_wallet_providers.dart';
import '../../../app/providers/nfc_access_providers.dart';
import '../../../app/providers/qr_providers.dart';
import '../../../domain/entities/wallet_card.dart';
import '../../../domain/value_objects/card_status.dart';
import '../../../presentation/layouts/section_shell.dart';

enum ClientCardAccessMode { qr, nfc }

class ClientCardAccessScreen extends ConsumerStatefulWidget {
  const ClientCardAccessScreen({
    required this.walletCardId,
    required this.mode,
    super.key,
  });

  final String walletCardId;
  final ClientCardAccessMode mode;

  @override
  ConsumerState<ClientCardAccessScreen> createState() =>
      _ClientCardAccessScreenState();
}

class _ClientCardAccessScreenState
    extends ConsumerState<ClientCardAccessScreen> {
  String? _qrData;
  DateTime? _issuedAt;
  bool _isPreparing = false;
  bool _isUpdating = false;
  String? _errorMessage;

  bool get _isQr => widget.mode == ClientCardAccessMode.qr;

  @override
  Widget build(BuildContext context) {
    final card = ref.watch(clientWalletCardProvider(widget.walletCardId));

    return SectionShell(
      title: _isQr ? 'QR Access' : 'NFC Access',
      child: card.when(
        data: (card) {
          if (card == null) {
            return const Center(child: Text('Card not found.'));
          }
          if (card.status != CardStatus.active) {
            return const Center(
              child: Text(
                'Access is available only for active cards.',
                textAlign: TextAlign.center,
              ),
            );
          }
          if (!_isPreparing && _errorMessage == null) {
            final shouldPrepare = _isQr ? _qrData == null : _issuedAt == null;
            if (shouldPrepare) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _prepareAccess(card);
                }
              });
            }
          }
          return _AccessContent(
            mode: widget.mode,
            card: card,
            qrData: _qrData,
            issuedAt: _issuedAt,
            isPreparing: _isPreparing,
            isUpdating: _isUpdating,
            errorMessage: _errorMessage,
            onRetry: () => _prepareAccess(card),
            onUpdate: _isPreparing || _isUpdating || _errorMessage != null
                ? null
                : () => _updateAndClose(card),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Could not load card: $error')),
      ),
    );
  }

  Future<void> _prepareAccess(WalletCard card) async {
    setState(() {
      _isPreparing = true;
      _errorMessage = null;
    });

    try {
      final qrService = ref.read(qrServiceProvider);
      final payload = await qrService.createDynamicChallenge(
        walletId: card.walletId,
        cardId: card.cardId,
      );
      final rawPayload = qrService.encodeDynamicChallenge(payload);

      if (_isQr) {
        if (!mounted) {
          return;
        }
        setState(() {
          _qrData = rawPayload;
          _issuedAt = payload.timestamp;
          _isPreparing = false;
        });
        return;
      }

      await ref.read(nfcAccessServiceProvider).writePayload(rawPayload);
      if (!mounted) {
        return;
      }
      setState(() {
        _issuedAt = payload.timestamp;
        _isPreparing = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _qrData = null;
        _issuedAt = null;
        _isPreparing = false;
        _errorMessage = _isQr
            ? 'Could not generate QR: $error'
            : 'Could not prepare NFC: $error';
      });
    }
  }

  Future<void> _updateAndClose(WalletCard card) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      await ref
          .read(clientWalletImportControllerProvider)
          .updateMyCard(card.walletCardId);
      if (mounted) {
        context.pop();
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isUpdating = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update card: $error')));
    }
  }
}

class _AccessContent extends StatelessWidget {
  const _AccessContent({
    required this.mode,
    required this.card,
    required this.qrData,
    required this.issuedAt,
    required this.isPreparing,
    required this.isUpdating,
    required this.errorMessage,
    required this.onRetry,
    required this.onUpdate,
  });

  final ClientCardAccessMode mode;
  final WalletCard card;
  final String? qrData;
  final DateTime? issuedAt;
  final bool isPreparing;
  final bool isUpdating;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback? onUpdate;

  bool get _isQr => mode == ClientCardAccessMode.qr;

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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (isPreparing)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  )
                else if (errorMessage != null) ...[
                  Text(errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                    onPressed: onRetry,
                  ),
                ] else if (_isQr && qrData != null) ...[
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
                ] else if (!_isQr) ...[
                  const Icon(Icons.nfc, size: 72),
                  const SizedBox(height: 16),
                  Text(
                    'Hold the phone near the scanner.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
                if (issuedAt != null && errorMessage == null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Generated at ${_timeLabel(issuedAt!)}',
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'After the business scans this access code, tap Update to refresh this phone wallet locally.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.done_all),
          label: Text(isUpdating ? 'Updating...' : 'Update local card'),
          onPressed: onUpdate,
        ),
      ],
    );
  }
}

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final second = local.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

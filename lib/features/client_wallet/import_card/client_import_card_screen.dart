import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/providers/client_wallet_providers.dart';
import '../../../app/providers/nfc_access_providers.dart';
import '../../../core/constants/route_names.dart';
import '../../../domain/entities/subscription_import_payload.dart';
import '../../../presentation/layouts/section_shell.dart';

class ClientImportCardScreen extends ConsumerStatefulWidget {
  const ClientImportCardScreen({super.key});

  @override
  ConsumerState<ClientImportCardScreen> createState() =>
      _ClientImportCardScreenState();
}

class _ClientImportCardScreenState
    extends ConsumerState<ClientImportCardScreen> {
  final _scannerController = MobileScannerController();
  bool _handlingScan = false;
  bool _handlingNfc = false;
  String? _message;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionShell(
      title: 'Import Card',
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
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.nfc),
                    label: Text(
                      _handlingNfc ? 'Waiting for NFC...' : 'Import by NFC',
                    ),
                    onPressed: _handlingNfc ? null : _readNfc,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Scan the QR received from the business to add the card to the wallet.',
                    textAlign: TextAlign.center,
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(_message!, textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
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
      final imported = await _importRawPayload(rawValue);
      if (!imported && mounted) {
        await _scannerController.start();
        _handlingScan = false;
      }
    } on FormatException catch (error) {
      await _showScanError(error.message);
    } on Object catch (error) {
      await _showScanError('Import failed: $error');
    }
  }

  Future<void> _readNfc() async {
    setState(() {
      _handlingNfc = true;
      _message = null;
    });

    try {
      final rawPayload = await ref
          .read(nfcAccessServiceProvider)
          .receivePayload();
      await _importRawPayload(rawPayload);
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _message = error.message);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _message = 'NFC import failed: $error');
    } finally {
      if (mounted) {
        setState(() => _handlingNfc = false);
      }
    }
  }

  Future<bool> _importRawPayload(String rawPayload) async {
    final controller = ref.read(clientWalletImportControllerProvider);
    final payload = controller.decode(rawPayload);
    final existing = await controller.findExisting(payload);

    if (!mounted) {
      return false;
    }

    if (existing != null) {
      final update = await _confirmUpdate(payload);
      if (update != true) {
        setState(() => _message = 'The card already exists in the wallet.');
        return false;
      }
    }

    final importedCard = await controller.importPayload(
      payload,
      updateExisting: true,
    );

    if (!mounted) {
      return false;
    }
    if (importedCard == null) {
      context.go(RouteNames.clientCards);
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_cardTypeLabel(payload.cardType)} imported.')),
    );
    context.go('/client/cards/${importedCard.walletCardId}');
    return true;
  }

  Future<bool?> _confirmUpdate(SubscriptionImportPayload payload) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Card Already Imported'),
        content: Text(
          '${_cardTypeLabel(payload.cardType)} "${payload.cardTitle}" already exists in the wallet. Do you want to update it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _showScanError(String message) async {
    if (!mounted) {
      return;
    }
    setState(() => _message = message);
    await _scannerController.start();
    _handlingScan = false;
  }
}

String _cardTypeLabel(String cardType) {
  return switch (cardType) {
    'loyalty' => 'Loyalty Card',
    _ => 'Membership',
  };
}

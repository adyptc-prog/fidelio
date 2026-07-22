import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/providers/business_profile_providers.dart';
import '../../../app/providers/business_subscriptions_providers.dart';
import '../../../app/providers/nfc_access_providers.dart';
import '../../../app/providers/qr_providers.dart';
import '../../../domain/entities/business_profile.dart';
import '../../../domain/entities/subscription_card.dart';
import '../../../domain/value_objects/card_status.dart';
import '../../../domain/value_objects/subscription_type.dart';
import '../../../presentation/layouts/section_shell.dart';

class BusinessSubscriptionDetailsScreen extends ConsumerWidget {
  const BusinessSubscriptionDetailsScreen({
    required this.subscriptionId,
    super.key,
  });

  final String subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionByIdProvider(subscriptionId));
    final business = ref.watch(businessProfileControllerProvider);

    return SectionShell(
      title: 'Membership',
      child: subscription.when(
        data: (subscription) {
          if (subscription == null) {
            return const Center(child: Text('Membership not found.'));
          }

          return business.when(
            data: (business) {
              if (business == null) {
                return const Center(
                  child: Text('Business profile is not configured.'),
                );
              }
              return _SubscriptionDetails(
                business: business,
                subscription: subscription,
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                Center(child: Text('Could not load business: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Could not load membership: $error')),
      ),
    );
  }
}

class _SubscriptionDetails extends ConsumerStatefulWidget {
  const _SubscriptionDetails({
    required this.business,
    required this.subscription,
  });

  final BusinessProfile business;
  final SubscriptionCard subscription;

  @override
  ConsumerState<_SubscriptionDetails> createState() =>
      _SubscriptionDetailsState();
}

class _SubscriptionDetailsState extends ConsumerState<_SubscriptionDetails> {
  bool _showQr = false;
  bool _isWritingNfc = false;
  bool _isDeleting = false;
  String? _nfcMessage;

  @override
  Widget build(BuildContext context) {
    final qrService = ref.watch(qrServiceProvider);
    final payload = qrService.createSubscriptionImportPayload(
      business: widget.business,
      subscription: widget.subscription,
    );
    final qrData = qrService.encodeSubscriptionImportPayload(payload);
    final status = widget.subscription.effectiveStatus;
    final hasNoEntries =
        widget.subscription.remainingUses != null &&
        widget.subscription.remainingUses! <= 0;

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.subscription.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                _InfoLine(
                  label: 'Type',
                  value: _typeLabel(widget.subscription.subscriptionType),
                ),
                _InfoLine(label: 'Status', value: _statusLabel(status)),
                if (hasNoEntries)
                  const _InfoLine(
                    label: 'Scan',
                    value: 'inavailable - no entries',
                  ),
                _InfoLine(
                  label: 'Valid',
                  value:
                      '${_dateOrDash(widget.subscription.startsAt)} - ${_dateOrDash(widget.subscription.expiresAt)}',
                ),
                _InfoLine(
                  label: 'Entries',
                  value: widget.subscription.remainingUses?.toString() ?? '-',
                ),
                _InfoLine(
                  label: 'Observatii',
                  value: widget.subscription.notes ?? '-',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.qr_code_2),
          label: const Text('Send to Client by QR'),
          onPressed: () => setState(() => _showQr = true),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.nfc),
          label: Text(
            _isWritingNfc ? 'Preparing NFC...' : 'Send to Client by NFC',
          ),
          onPressed: _isWritingNfc ? null : () => _writeNfc(qrData),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_outline),
          label: Text(_isDeleting ? 'Deleting...' : 'Delete Membership'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _isDeleting ? null : _deleteSubscription,
        ),
        if (_nfcMessage != null) ...[
          const SizedBox(height: 8),
          Text(_nfcMessage!, textAlign: TextAlign.center),
        ],
        if (_showQr) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'The client scans this code from Client Mode to add the card to the wallet',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 280,
                    backgroundColor: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _deleteSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete membership?'),
        content: const Text(
          'Are you sure you want to permanently delete this membership from the local database?',
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
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      await ref
          .read(businessSubscriptionActionsProvider)
          .deleteSubscription(widget.subscription.cardId);
      if (mounted) {
        context.pop();
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete membership: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _writeNfc(String rawPayload) async {
    setState(() {
      _isWritingNfc = true;
      _nfcMessage =
          'Waiting for the client phone. Ask the client to tap Import by NFC and hold it near this device.';
    });

    try {
      await ref.read(nfcAccessServiceProvider).sendPayload(rawPayload);
      if (!mounted) {
        return;
      }
      setState(
        () => _nfcMessage = 'Card sent by NFC.',
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _nfcMessage = 'NFC export failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isWritingNfc = false);
      }
    }
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

String _typeLabel(SubscriptionType type) {
  return switch (type) {
    SubscriptionType.monthly => 'monthly',
    SubscriptionType.entries => 'entry count',
    SubscriptionType.custom => 'custom',
  };
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

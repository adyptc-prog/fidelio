import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/providers/business_profile_providers.dart';
import '../../../app/providers/business_subscriptions_providers.dart';
import '../../../app/providers/nfc_access_providers.dart';
import '../../../app/providers/qr_providers.dart';
import '../../../domain/entities/business_profile.dart';
import '../../../domain/entities/loyalty_card.dart';
import '../../../domain/value_objects/card_status.dart';
import '../../../domain/value_objects/loyalty_program_type.dart';
import '../../../presentation/layouts/section_shell.dart';

class BusinessLoyaltyDetailsScreen extends ConsumerWidget {
  const BusinessLoyaltyDetailsScreen({required this.loyaltyId, super.key});

  final String loyaltyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loyaltyCard = ref.watch(loyaltyCardByIdProvider(loyaltyId));
    final business = ref.watch(businessProfileControllerProvider);

    return SectionShell(
      title: 'Loyalty Card',
      child: loyaltyCard.when(
        data: (card) {
          if (card == null) {
            return const Center(child: Text('Card not found.'));
          }
          return business.when(
            data: (business) {
              if (business == null) {
                return const Center(
                  child: Text('Business profile is not configured.'),
                );
              }
              return _LoyaltyDetails(business: business, card: card);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                Center(child: Text('Could not load business: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Could not load card: $error')),
      ),
    );
  }
}

class _LoyaltyDetails extends ConsumerStatefulWidget {
  const _LoyaltyDetails({required this.business, required this.card});

  final BusinessProfile business;
  final LoyaltyCard card;

  @override
  ConsumerState<_LoyaltyDetails> createState() => _LoyaltyDetailsState();
}

class _LoyaltyDetailsState extends ConsumerState<_LoyaltyDetails> {
  bool _showQr = false;
  bool _isWritingNfc = false;
  bool _isAddingStamp = false;
  bool _isRedeemingReward = false;
  bool _isDeleting = false;
  String? _nfcMessage;

  @override
  Widget build(BuildContext context) {
    final isDelivery = widget.card.programType == LoyaltyProgramType.delivery;
    final qrData = isDelivery ? null : _qrData();

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.card.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                _InfoLine(
                  label: 'Status',
                  value: _statusValue(widget.card),
                ),
                _InfoLine(
                  label: _progressLabel(widget.card.programType),
                  value: _progressValue(widget.card),
                ),
                if (widget.card.programType == LoyaltyProgramType.points)
                  _InfoLine(
                    label: 'Rule',
                    value: '${widget.card.pointsPerScan ?? 10} points/scan',
                  ),
                if (widget.card.programType ==
                    LoyaltyProgramType.visitChallenge)
                  _InfoLine(
                    label: 'Period',
                    value:
                        '${widget.card.challengeWindowDays ?? 30} days'
                        '${_challengeEndsAt(widget.card)}',
                  ),
                _InfoLine(
                  label: 'Reward',
                  value: _rewardValue(widget.card),
                ),
                _InfoLine(label: 'Card ID', value: widget.card.cardId),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (isDelivery)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.card.isCompleted)
                const Text(
                  'This card has been fully used. Create a new card for this client.',
                  textAlign: TextAlign.center,
                )
              else ...[
                FilledButton.icon(
                  icon: const Icon(Icons.add_task),
                  label: Text(_isAddingStamp ? 'Updating...' : 'Add Stamp'),
                  onPressed:
                      (_isAddingStamp ||
                          widget.card.currentStamps >=
                              widget.card.rewardThreshold)
                      ? null
                      : _addDeliveryStamp,
                ),
                if (widget.card.currentStamps >=
                    widget.card.rewardThreshold) ...[
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.stars),
                    label: Text(
                      _isRedeemingReward
                          ? 'Redeeming...'
                          : 'Redeem Bonus Entry',
                    ),
                    onPressed: _isRedeemingReward
                        ? null
                        : _redeemDeliveryReward,
                  ),
                ],
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: Text(_isDeleting ? 'Deleting...' : 'Delete Card'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: _isDeleting ? null : _deleteCard,
              ),
            ],
          )
        else ...[
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
            onPressed: _isWritingNfc ? null : () => _writeNfc(qrData!),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: Text(_isDeleting ? 'Deleting...' : 'Delete Card'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: _isDeleting ? null : _deleteCard,
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
                      'The client scans this code from Client Mode to add the card to the wallet.',
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
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  String _qrData() {
    final qrService = ref.watch(qrServiceProvider);
    final payload = qrService.createLoyaltyImportPayload(
      business: widget.business,
      loyaltyCard: widget.card,
    );
    return qrService.encodeSubscriptionImportPayload(payload);
  }

  Future<void> _addDeliveryStamp() async {
    setState(() => _isAddingStamp = true);
    try {
      final updated = await ref
          .read(businessSubscriptionActionsProvider)
          .addDeliveryStamp(widget.card.cardId);
      if (!mounted || updated == null) {
        return;
      }
      final rewardMessage = updated.isBonusPending
          ? ' All entries reached! The next entry will be the bonus one.'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stamp added. Progress: ${updated.currentStamps}/${updated.rewardThreshold}.$rewardMessage',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add stamp: $error')));
    } finally {
      if (mounted) {
        setState(() => _isAddingStamp = false);
      }
    }
  }

  Future<void> _redeemDeliveryReward() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redeem bonus entry?'),
        content: const Text(
          'This entry is bonus. After redeeming it, this card will be fully used and cannot be used again — a new card will be needed for this client.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isRedeemingReward = true);
    try {
      final updated = await ref
          .read(businessSubscriptionActionsProvider)
          .redeemDeliveryReward(widget.card.cardId);
      if (!mounted || updated == null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This entry is bonus! Card is now fully used — create a new card for this client.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not redeem reward: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isRedeemingReward = false);
      }
    }
  }

  Future<void> _deleteCard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete card?'),
        content: const Text(
          'Are you sure you want to permanently delete this card from the local database?',
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
          .deleteLoyaltyCard(widget.card.cardId);
      if (mounted) {
        context.pop();
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete card: $error')));
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
      setState(() => _nfcMessage = 'Card sent by NFC.');
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

String _progressLabel(LoyaltyProgramType type) {
  return switch (type) {
    LoyaltyProgramType.stamps => 'Stamps',
    LoyaltyProgramType.points => 'Points',
    LoyaltyProgramType.visitChallenge => 'Visits',
    LoyaltyProgramType.delivery => 'Stamps',
  };
}

String _progressValue(LoyaltyCard card) {
  return '${card.currentStamps}/${card.rewardThreshold}';
}

String _statusValue(LoyaltyCard card) {
  if (card.isCompleted) {
    return 'fully used';
  }
  return _statusLabel(card.status);
}

String _rewardValue(LoyaltyCard card) {
  if (card.isCompleted) {
    return 'fully used — create a new card';
  }
  if (card.isBonusPending) {
    return 'next entry is bonus';
  }
  return _remainingValue(card);
}

String _remainingValue(LoyaltyCard card) {
  final remaining = card.rewardThreshold - card.currentStamps;
  return switch (card.programType) {
    LoyaltyProgramType.stamps => '$remaining stamps remaining',
    LoyaltyProgramType.points => '$remaining points remaining',
    LoyaltyProgramType.visitChallenge => '$remaining visits remaining',
    LoyaltyProgramType.delivery => '$remaining stamps remaining',
  };
}

String _challengeEndsAt(LoyaltyCard card) {
  final startedAt = card.challengeStartedAt;
  if (startedAt == null) {
    return '';
  }
  final expiresAt = startedAt.add(
    Duration(days: card.challengeWindowDays ?? 30),
  );
  return ', until ${_formatDate(expiresAt)}';
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
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

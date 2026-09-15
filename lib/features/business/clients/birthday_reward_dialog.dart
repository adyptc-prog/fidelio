import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/business_customers_providers.dart';
import '../../../app/providers/business_profile_providers.dart';
import '../../../app/providers/business_subscriptions_providers.dart';
import '../../../domain/entities/customer_record.dart';
import '../../../domain/entities/loyalty_card.dart';
import '../../../domain/value_objects/card_status.dart';
import 'birthday_reward_card_screen.dart';

/// Shows the "grant a birthday reward?" prompt for [customer]. Handles the
/// whole flow: Yes/No choice, picking a loyalty card when the customer has
/// more than one, granting the bonus entry, and opening the shareable
/// birthday card. Always marks the customer as prompted for this year,
/// regardless of the outcome.
Future<void> showBirthdayRewardDialog(
  BuildContext context, {
  required CustomerRecord customer,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _BirthdayRewardDialog(customer: customer),
  );
}

class _BirthdayRewardDialog extends ConsumerStatefulWidget {
  const _BirthdayRewardDialog({required this.customer});

  final CustomerRecord customer;

  @override
  ConsumerState<_BirthdayRewardDialog> createState() =>
      _BirthdayRewardDialogState();
}

class _BirthdayRewardDialogState extends ConsumerState<_BirthdayRewardDialog> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Birthday Reward'),
      content: Text(
        'Do you want to grant a reward for ${widget.customer.displayName}\'s '
        'birthday?',
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : _decline,
          child: const Text('No'),
        ),
        FilledButton(
          onPressed: _isProcessing ? null : _accept,
          child: Text(_isProcessing ? 'Working...' : 'Yes'),
        ),
      ],
    );
  }

  Future<void> _decline() async {
    await _markPrompted();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _accept() async {
    setState(() => _isProcessing = true);

    final business = await ref.read(businessProfileControllerProvider.future);
    if (business == null || !mounted) {
      await _markPrompted();
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    final allCards = await ref.read(
      customerLoyaltyCardsProvider(widget.customer.customerId).future,
    );
    final eligibleCards = allCards
        .where(
          (card) =>
              card.businessId == business.businessId &&
              card.status == CardStatus.active &&
              !card.isCompleted,
        )
        .toList();

    if (!mounted) {
      return;
    }

    if (eligibleCards.isEmpty) {
      await _markPrompted();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.customer.displayName} has no active loyalty card to reward.',
          ),
        ),
      );
      return;
    }

    LoyaltyCard? target = eligibleCards.first;
    if (eligibleCards.length > 1) {
      target = await _pickCard(eligibleCards);
      if (target == null) {
        setState(() => _isProcessing = false);
        return;
      }
    }

    try {
      await ref
          .read(businessSubscriptionActionsProvider)
          .grantBonusEntry(target.cardId);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not grant the reward: $error')),
      );
      return;
    }

    await _markPrompted();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BirthdayRewardCardScreen(
          customerName: widget.customer.displayName,
          businessName: business.displayName,
        ),
      ),
    );
  }

  Future<LoyaltyCard?> _pickCard(List<LoyaltyCard> cards) {
    return showDialog<LoyaltyCard>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Which card gets the reward?'),
        children: cards
            .map(
              (card) => SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(card),
                child: Text(card.name),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _markPrompted() {
    return ref
        .read(businessCustomersControllerProvider.notifier)
        .markBirthdayPrompted(widget.customer.customerId);
  }
}

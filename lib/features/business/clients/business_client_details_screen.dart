import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/business_customers_providers.dart';
import '../../../app/providers/business_subscriptions_providers.dart';
import '../../../domain/entities/customer_record.dart';
import '../../../domain/entities/loyalty_card.dart';
import '../../../domain/entities/subscription_card.dart';
import '../../../domain/value_objects/card_status.dart';
import '../../../domain/value_objects/customer_status.dart';
import '../../../domain/value_objects/loyalty_program_type.dart';
import '../../../domain/value_objects/subscription_type.dart';
import '../../../presentation/layouts/section_shell.dart';
import 'customer_form_dialog.dart';
import 'loyalty_form_dialog.dart';
import 'subscription_form_dialog.dart';

class BusinessClientDetailsScreen extends ConsumerWidget {
  const BusinessClientDetailsScreen({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersState = ref.watch(businessCustomersControllerProvider);

    return SectionShell(
      title: 'Customer Details',
      child: customersState.when(
        data: (state) {
          final customer = state.customers
              .where((customer) => customer.customerId == customerId)
              .firstOrNull;
          if (customer == null) {
            return const Center(child: Text('Customer not found.'));
          }
          return _CustomerDetails(customer: customer);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Could not load customer details: $error')),
      ),
    );
  }
}

class _CustomerDetails extends ConsumerWidget {
  const _CustomerDetails({required this.customer});

  final CustomerRecord customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                _InfoLine(
                  label: 'Status',
                  value: customer.status == CustomerStatus.active
                      ? 'active'
                      : 'inactive',
                ),
                _InfoLine(label: 'Phone', value: customer.phone ?? '-'),
                _InfoLine(label: 'Email', value: customer.email ?? '-'),
                _InfoLine(label: 'Notes', value: customer.notes ?? '-'),
                _InfoLine(label: 'ID', value: customer.customerId),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.card_membership),
          label: const Text('Create Membership'),
          onPressed: customer.status == CustomerStatus.inactive
              ? null
              : () => showSubscriptionFormDialog(context, customer: customer),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.loyalty),
          label: const Text('Create Loyalty Card'),
          onPressed: customer.status == CustomerStatus.inactive
              ? null
              : () => showLoyaltyFormDialog(context, customer: customer),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.edit),
          label: const Text('Edit Customer'),
          onPressed: () => showCustomerFormDialog(context, customer: customer),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete Customer'),
          onPressed: () => _deleteCustomer(context, ref),
        ),
        const SizedBox(height: 16),
        Text('Memberships', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        _CustomerSubscriptions(customerId: customer.customerId),
        const SizedBox(height: 16),
        Text('Loyalty Cards', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        _CustomerLoyaltyCards(customer: customer),
      ],
    );
  }

  Future<void> _deleteCustomer(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete customer?'),
        content: const Text(
          'Are you sure you want to permanently delete this customer from the local database?',
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

    if (confirmed != true) {
      return;
    }

    await ref
        .read(businessCustomersControllerProvider.notifier)
        .deleteCustomer(customer.customerId);
    if (context.mounted) {
      context.pop();
    }
  }
}

class _CustomerLoyaltyCards extends ConsumerWidget {
  const _CustomerLoyaltyCards({required this.customer});

  final CustomerRecord customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loyaltyCards = ref.watch(
      customerLoyaltyCardsProvider(customer.customerId),
    );

    return loyaltyCards.when(
      data: (cards) {
        final customerCards = cards;
        if (customerCards.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('The customer does not have loyalty cards yet.'),
            ),
          );
        }

        return Column(
          children: customerCards
              .map(
                (card) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LoyaltyTile(card: card),
                ),
              )
              .toList(),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Could not load loyalty cards: $error'),
        ),
      ),
    );
  }
}

class _LoyaltyTile extends StatelessWidget {
  const _LoyaltyTile({required this.card});

  final LoyaltyCard card;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(_statusIcon(card.status)),
        title: Text(card.name),
        subtitle: Text(_loyaltyProgress(card)),
        trailing: Text(_statusLabel(card.status)),
        onTap: () => context.push('/business/loyalty/${card.cardId}'),
      ),
    );
  }

  IconData _statusIcon(CardStatus status) {
    return switch (status) {
      CardStatus.active => Icons.check_circle,
      CardStatus.expired => Icons.event_busy,
      CardStatus.suspended => Icons.pause_circle,
      CardStatus.cancelled => Icons.cancel,
      CardStatus.draft || CardStatus.revoked => Icons.info,
    };
  }
}

String _loyaltyProgress(LoyaltyCard card) {
  return switch (card.programType) {
    LoyaltyProgramType.stamps =>
      '${card.currentStamps}/${card.rewardThreshold} stamps',
    LoyaltyProgramType.points =>
      '${card.currentStamps}/${card.rewardThreshold} points',
    LoyaltyProgramType.visitChallenge =>
      '${card.currentStamps}/${card.rewardThreshold} visits',
    LoyaltyProgramType.delivery =>
      '${card.currentStamps}/${card.rewardThreshold} stamps',
  };
}

class _CustomerSubscriptions extends ConsumerWidget {
  const _CustomerSubscriptions({required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions = ref.watch(customerSubscriptionsProvider(customerId));

    return subscriptions.when(
      data: (subscriptions) {
        if (subscriptions.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('The customer does not have memberships yet.'),
            ),
          );
        }

        return Column(
          children: subscriptions
              .map(
                (subscription) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SubscriptionTile(subscription: subscription),
                ),
              )
              .toList(),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Could not load memberships: $error'),
        ),
      ),
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile({required this.subscription});

  final SubscriptionCard subscription;

  @override
  Widget build(BuildContext context) {
    final status = subscription.effectiveStatus;

    return Card(
      child: ListTile(
        leading: Icon(_statusIcon(status)),
        title: Text(subscription.name),
        subtitle: Text(_subtitle),
        trailing: Text(_statusLabel(status)),
        onTap: () =>
            context.push('/business/subscriptions/${subscription.cardId}'),
      ),
    );
  }

  String get _subtitle {
    final parts = [
      _typeLabel(subscription.subscriptionType),
      if (subscription.startsAt != null)
        'starts ${_formatDate(subscription.startsAt!)}',
      if (subscription.expiresAt != null)
        'expires ${_formatDate(subscription.expiresAt!)}',
      if (subscription.remainingUses != null)
        '${subscription.remainingUses} entries',
    ];
    return parts.join(' - ');
  }

  IconData _statusIcon(CardStatus status) {
    return switch (status) {
      CardStatus.active => Icons.check_circle,
      CardStatus.expired => Icons.event_busy,
      CardStatus.suspended => Icons.pause_circle,
      CardStatus.cancelled => Icons.cancel,
      CardStatus.draft || CardStatus.revoked => Icons.info,
    };
  }
}

String _formatDate(DateTime value) {
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

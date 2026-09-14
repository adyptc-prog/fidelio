import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/business_customers_providers.dart';
import '../../../domain/entities/customer_record.dart';
import '../../../domain/services/customer_rank_service.dart';
import '../../../presentation/layouts/section_shell.dart';
import '../../../presentation/widgets/customer_rank_badge.dart';

class BusinessLeaderboardScreen extends ConsumerWidget {
  const BusinessLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersState = ref.watch(businessCustomersControllerProvider);

    return SectionShell(
      title: 'Leaderboard',
      child: customersState.when(
        data: (state) {
          if (state.customers.isEmpty) {
            return const Center(
              child: Text('No customers yet.', textAlign: TextAlign.center),
            );
          }

          final ranked = sortCustomersByRank(state.customers);
          return ListView.separated(
            itemCount: ranked.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final customer = ranked[index];
              final rank = rankForRewards(customer.rewardsEarned);
              return Card(
                child: ListTile(
                  leading: CustomerRankBadge(rank: rank, iconSize: 28),
                  title: Text(customer.displayName),
                  subtitle: Text(
                    '${rankLabel(rank)} · ${customer.rewardsEarned} rewards',
                  ),
                  trailing: Text(
                    _lastVisitLabel(customer),
                    textAlign: TextAlign.right,
                  ),
                  onTap: () =>
                      context.push('/business/clients/${customer.customerId}'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Could not load customers: $error')),
      ),
    );
  }
}

String _lastVisitLabel(CustomerRecord customer) {
  final lastVisitAt = customer.lastVisitAt;
  if (lastVisitAt == null) {
    return 'Never visited';
  }
  return 'Last visit\n${_formatDate(lastVisitAt)}';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

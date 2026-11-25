import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/business_check_in_providers.dart';
import '../../../app/providers/business_customers_providers.dart';
import '../../../app/providers/business_subscriptions_providers.dart';
import '../../../app/providers/business_profile_providers.dart';
import '../../../domain/entities/check_in_event.dart';
import '../../../presentation/layouts/section_shell.dart';
import 'package:fidelio/app/localization/app_language.dart';

class BusinessScanHistoryScreen extends ConsumerWidget {
  const BusinessScanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(businessProfileControllerProvider);

    return SectionShell(
      title: t('Recent Scans'),
      child: business.when(
        data: (business) {
          if (business == null) {
            return Center(
              child: Text(t('Business profile is not configured.')),
            );
          }
          final checkIns = ref.watch(
            businessCheckInsProvider(business.businessId),
          );
          return checkIns.when(
            data: (events) => _ScanHistoryList(
              events: events,
              names:
                  ref.watch(_cardOwnerNamesProvider(business.businessId)).value ??
                  const {},
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                Center(child: Text(tr('Scanările nu au putut fi încărcate: $error', 'Could not load scans: $error'))),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text(tr('Nu s-a putut încărca afacerea: $error', 'Could not load business: $error'))),
      ),
    );
  }
}

class _ScanHistoryList extends StatelessWidget {
  const _ScanHistoryList({required this.events, required this.names});

  final List<CheckInEvent> events;

  /// cardId sau customerId → numele clientului.
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final sortedEvents = [...events]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    if (sortedEvents.isEmpty) {
      return Center(child: Text(t('No scans recorded yet.')));
    }

    return ListView.separated(
      itemCount: sortedEvents.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final event = sortedEvents[index];
        return Card(
          child: ListTile(
            leading: Icon(
              event.result == 'valid' ? Icons.check_circle : Icons.info,
            ),
            title: Text(_resultLabel(event.result)),
            subtitle: Text(
              '${names[event.customerId] ?? names[event.cardId] ?? (names.isEmpty ? event.cardId : t('Deleted card'))}'
              ' - ${_dateTimeLabel(event.occurredAt)}',
            ),
          ),
        );
      },
    );
  }
}

String _resultLabel(String? result) {
  return switch (result) {
    'valid' => t('Scan Validated'),
    'invalid QR' => t('Invalid or Expired QR'),
    'reused QR' => t('QR Already Used'),
    'expired' => t('Card expired'),
    'no entries' => t('No Entries'),
    'suspended' => t('Card Suspended'),
    _ => t('Scan Rejected'),
  };
}

String _dateTimeLabel(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

/// Numele clienților, după ID-ul cardului și al clientului — ca lista de
/// scanări să arate „Maria Popescu”, nu „loyalty-1795…”.
final _cardOwnerNamesProvider =
    FutureProvider.autoDispose.family<Map<String, String>, String>((
      ref,
      businessId,
    ) async {
      final customers = await ref
          .read(customerRepositoryProvider)
          .listCustomers(businessId);
      final byCustomer = {for (final c in customers) c.customerId: c.displayName};
      final cards = ref.read(cardRepositoryProvider);
      final names = <String, String>{...byCustomer};
      for (final card in await cards.listSubscriptionCards(businessId)) {
        final name = byCustomer[card.customerId];
        if (name != null) names[card.cardId] = name;
      }
      for (final card in await cards.listLoyaltyCards(businessId)) {
        final name = byCustomer[card.customerId];
        if (name != null) names[card.cardId] = name;
      }
      return names;
    });

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/business_check_in_providers.dart';
import '../../../app/providers/business_profile_providers.dart';
import '../../../domain/entities/check_in_event.dart';
import '../../../presentation/layouts/section_shell.dart';

class BusinessScanHistoryScreen extends ConsumerWidget {
  const BusinessScanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(businessProfileControllerProvider);

    return SectionShell(
      title: 'Recent Scans',
      child: business.when(
        data: (business) {
          if (business == null) {
            return const Center(
              child: Text('Business profile is not configured.'),
            );
          }
          final checkIns = ref.watch(
            businessCheckInsProvider(business.businessId),
          );
          return checkIns.when(
            data: (events) => _ScanHistoryList(events: events),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                Center(child: Text('Could not load scans: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Could not load business: $error')),
      ),
    );
  }
}

class _ScanHistoryList extends StatelessWidget {
  const _ScanHistoryList({required this.events});

  final List<CheckInEvent> events;

  @override
  Widget build(BuildContext context) {
    final sortedEvents = [...events]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    if (sortedEvents.isEmpty) {
      return const Center(child: Text('No scans recorded yet.'));
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
              '${event.cardId} - ${_dateTimeLabel(event.occurredAt)}',
            ),
          ),
        );
      },
    );
  }
}

String _resultLabel(String? result) {
  return switch (result) {
    'valid' => 'Scan validata',
    'invalid QR' => 'Invalid or Expired QR',
    'reused QR' => 'QR Already Used',
    'expired' => 'Card expired',
    'no entries' => 'No Entries',
    'suspended' => 'Card Suspended',
    _ => 'Scan Rejected',
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

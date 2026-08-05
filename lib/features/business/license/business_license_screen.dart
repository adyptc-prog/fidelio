import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/business_profile_providers.dart';
import '../../../app/providers/business_subscriptions_providers.dart';
import '../../../app/providers/license_providers.dart';
import '../../../domain/entities/license_status.dart';
import '../../../presentation/layouts/section_shell.dart';

class BusinessLicenseScreen extends ConsumerWidget {
  const BusinessLicenseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(businessProfileControllerProvider);

    return SectionShell(
      title: 'License',
      child: business.when(
        data: (business) {
          if (business == null) {
            return const Center(
              child: Text('Business profile is not configured.'),
            );
          }

          final status = ref.watch(
            businessLicenseStatusProvider(business.businessId),
          );
          final count = ref.watch(businessCardCountProvider(business.businessId));

          return ListView(
            children: [
              status.when(
                data: (status) => _LicenseStatusCard(
                  status: status,
                  onRefresh: () => _refresh(ref, business.businessId),
                  onSelect: () => _selectLicense(ref, business.businessId),
                ),
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (error, stackTrace) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Could not check license: $error'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.store),
                  title: const Text('Business ID'),
                  subtitle: Text(business.businessId),
                  trailing: IconButton(
                    tooltip: 'Copy Business ID',
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: business.businessId),
                      );
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Business ID copied.')),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.credit_card),
                  title: const Text('Free limit'),
                  subtitle: Text(
                    count.when(
                      data: (count) => '$count/10 memberships and loyalty cards used',
                      loading: () => 'Loading card count...',
                      error: (error, stackTrace) => 'Could not load count: $error',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Buy a license at voltacademy.app/fidelio.html using the Business ID above, '
                    'then use "Select USB License" to import the downloaded fidelio_license.json '
                    '(from your phone storage or a USB-C stick). Placing it on a stick at '
                    '/Fidelio/fidelio_license.json also lets the app pick it up automatically.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Could not load business: $error')),
      ),
    );
  }

  Future<void> _selectLicense(WidgetRef ref, String businessId) async {
    await ref.read(usbLicenseServiceProvider).pickLicenseFile();
    ref.invalidate(businessLicenseStatusProvider(businessId));
  }

  void _refresh(WidgetRef ref, String businessId) {
    ref.invalidate(businessLicenseStatusProvider(businessId));
  }
}

class _LicenseStatusCard extends StatelessWidget {
  const _LicenseStatusCard({
    required this.status,
    required this.onRefresh,
    required this.onSelect,
  });

  final LicenseStatus status;
  final VoidCallback onRefresh;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final presentation = _LicensePresentation.fromStatus(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(presentation.icon, size: 48, color: presentation.color),
            const SizedBox(height: 8),
            Text(
              presentation.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(status.message, textAlign: TextAlign.center),
            if (status.licenseId != null) ...[
              const SizedBox(height: 12),
              Text('License: ${status.licenseId}', textAlign: TextAlign.center),
            ],
            if (status.validUntil != null) ...[
              const SizedBox(height: 6),
              Text(
                'Valid until: ${status.validUntil}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: status.isExpiringSoon ? Colors.orange : null,
                  fontWeight: status.isExpiringSoon ? FontWeight.bold : null,
                ),
              ),
            ],
            if (status.daysUntilExpiry != null) ...[
              const SizedBox(height: 4),
              Text(
                status.daysUntilExpiry! <= 1
                    ? 'Expires tomorrow!'
                    : '${status.daysUntilExpiry} days remaining',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: status.isExpiringSoon ? Colors.orange : null,
                  fontWeight: status.isExpiringSoon ? FontWeight.bold : null,
                ),
              ),
            ],
            if (status.path != null) ...[
              const SizedBox(height: 6),
              Text(status.path!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Check Again'),
              onPressed: onRefresh,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Select License File'),
              onPressed: onSelect,
            ),
          ],
        ),
      ),
    );
  }
}

class _LicensePresentation {
  const _LicensePresentation({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  factory _LicensePresentation.fromStatus(LicenseStatus status) {
    return switch (status.state) {
      LicenseState.active => _LicensePresentation(
        title: (status.isLifetime ?? true)
            ? 'Active Lifetime License'
            : 'Active License',
        icon: Icons.verified,
        color: status.isExpiringSoon ? Colors.orange : Colors.green,
      ),
      LicenseState.invalid => const _LicensePresentation(
        title: 'Invalid License',
        icon: Icons.error,
        color: Colors.red,
      ),
      LicenseState.missing => const _LicensePresentation(
        title: 'License Missing',
        icon: Icons.usb_off,
        color: Colors.orange,
      ),
    };
  }
}

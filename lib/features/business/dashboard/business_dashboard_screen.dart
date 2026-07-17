import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/business_customers_providers.dart';
import '../../../app/providers/business_check_in_providers.dart';
import '../../../app/providers/business_profile_providers.dart';
import '../../../app/providers/business_subscriptions_providers.dart';
import '../../../app/providers/license_providers.dart';
import '../../../core/constants/route_names.dart';
import '../../../domain/entities/license_status.dart';
import '../../../presentation/layouts/section_shell.dart';

class BusinessDashboardScreen extends ConsumerWidget {
  const BusinessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(businessProfileControllerProvider);
    final customers = ref.watch(businessCustomersControllerProvider);

    return SectionShell(
      title: 'Business Mode',
      showBackButton: false,
      child: business.when(
        data: (business) {
          if (business == null) {
            return const Center(
              child: Text('Business profile is not configured.'),
            );
          }

          final subscriptions = ref.watch(
            businessSubscriptionCardsProvider(business.businessId),
          );
          final loyaltyCards = ref.watch(
            businessLoyaltyCardsProvider(business.businessId),
          );
          final checkIns = ref.watch(
            businessCheckInsProvider(business.businessId),
          );

          final totalCards =
              (subscriptions.valueOrNull?.length ?? 0) +
              (loyaltyCards.valueOrNull?.length ?? 0);

          return ListView(
            children: [
              _MetricsCard(
                customers: customers.valueOrNull?.customers.length,
                subscriptions: subscriptions.valueOrNull?.length,
                loyaltyCards: loyaltyCards.valueOrNull?.length,
                hasLoading:
                    customers.isLoading ||
                    subscriptions.isLoading ||
                    loyaltyCards.isLoading,
                errorMessage:
                    customers.error?.toString() ??
                    subscriptions.error?.toString() ??
                    loyaltyCards.error?.toString() ??
                    checkIns.error?.toString(),
              ),
              const SizedBox(height: 12),
              _ScanHistoryEntryCard(
                scanCount: checkIns.valueOrNull?.length,
                isLoading: checkIns.isLoading,
                onTap: () => context.push(RouteNames.businessScanHistory),
              ),
              if (totalCards >= 10) ...[
                const SizedBox(height: 12),
                _LicenseStatusBanner(businessId: business.businessId),
              ],
              const SizedBox(height: 12),
              _DashboardActionsGrid(
                actions: [
                  _DashboardAction(
                    title: 'Customers',
                    icon: Icons.people,
                    colors: const [Color(0xFF0B3B34), Color(0xFF16705F)],
                    onTap: () => context.push(RouteNames.businessClients),
                  ),
                  _DashboardAction(
                    title: 'QR Scan',
                    icon: Icons.qr_code_scanner,
                    colors: const [Color(0xFF123A52), Color(0xFF2A7C96)],
                    onTap: () => context.push(RouteNames.businessScanner),
                  ),
                  _DashboardAction(
                    title: 'NFC',
                    icon: Icons.nfc,
                    colors: const [Color(0xFF4E2D6B), Color(0xFF8B5BC0)],
                    onTap: () => context.push(RouteNames.businessNfcScanner),
                  ),
                  _DashboardAction(
                    title: 'Settings',
                    icon: Icons.settings,
                    colors: const [Color(0xFF5D4210), Color(0xFFD6AA2F)],
                    onTap: () => context.push(RouteNames.businessSettings),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Could not load dashboard: $error')),
      ),
    );
  }
}

class _ScanHistoryEntryCard extends StatelessWidget {
  const _ScanHistoryEntryCard({
    required this.scanCount,
    required this.isLoading,
    required this.onTap,
  });

  final int? scanCount;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.history),
        title: const Text('Recent Scans'),
        subtitle: Text(
          isLoading
              ? 'Loading...'
              : scanCount == 0
              ? 'No scans recorded'
              : '$scanCount scans recorded',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({
    required this.customers,
    required this.subscriptions,
    required this.loyaltyCards,
    required this.hasLoading,
    required this.errorMessage,
  });

  final int? customers;
  final int? subscriptions;
  final int? loyaltyCards;
  final bool hasLoading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF071F1C), Color(0xFF0E4A40), Color(0xFF5D4210)],
        ),
        border: Border.all(color: Colors.white24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33061412),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _Metric(label: 'Customers', value: customers),
                ),
                Expanded(
                  child: _Metric(label: 'Memberships', value: subscriptions),
                ),
                Expanded(
                  child: _Metric(label: 'Loyalty', value: loyaltyCards),
                ),
              ],
            ),
            if (hasLoading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(color: Color(0xFFD6AA2F)),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                'Could not load all statistics: $errorMessage',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value?.toString() ?? '-',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
        ],
      ),
    );
  }
}

class _DashboardActionsGrid extends StatelessWidget {
  const _DashboardActionsGrid({required this.actions});

  final List<_DashboardAction> actions;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1,
      children: actions
          .map((action) => _DashboardActionTile(action: action))
          .toList(),
    );
  }
}

class _DashboardAction {
  const _DashboardAction({
    required this.title,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
}

class _LicenseStatusBanner extends ConsumerWidget {
  const _LicenseStatusBanner({required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(businessLicenseStatusProvider(businessId));

    return status.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (status) => switch (status.state) {
        LicenseState.active => Card(
          child: ListTile(
            leading: Icon(
              Icons.verified,
              color: status.isExpiringSoon ? Colors.orange : Colors.green,
            ),
            title: Text(
              status.isExpiringSoon ? 'License expiring soon' : 'License active',
            ),
            subtitle: Text(
              status.isExpiringSoon && status.daysUntilExpiry != null
                  ? status.daysUntilExpiry! <= 1
                      ? 'Expires tomorrow! Renew to avoid interruptions.'
                      : '${status.daysUntilExpiry} days remaining. Renew to avoid interruptions.'
                  : 'Unlimited cards enabled.',
            ),
          ),
        ),
        LicenseState.missing => Card(
          child: ListTile(
            leading: const Icon(Icons.usb_off, color: Colors.orange),
            title: const Text('License required'),
            subtitle: const Text('Free limit reached. Tap to configure.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(RouteNames.businessLicense),
          ),
        ),
        LicenseState.invalid => Card(
          child: ListTile(
            leading: Icon(Icons.error_outline, color: Colors.red.shade600),
            title: const Text('License invalid'),
            subtitle: Text(status.message),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(RouteNames.businessLicense),
          ),
        ),
      },
    );
  }
}

class _DashboardActionTile extends StatelessWidget {
  const _DashboardActionTile({required this.action});

  final _DashboardAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: action.onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: action.colors,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: action.colors.last.withValues(alpha: 0.28),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.icon, size: 34, color: Colors.white),
                const SizedBox(height: 10),
                Text(
                  action.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:go_router/go_router.dart';

import '../core/constants/route_names.dart';
import '../domain/value_objects/app_mode.dart';
import '../features/business/backup/business_backup_screen.dart';
import '../features/business/clients/business_client_details_screen.dart';
import '../features/business/clients/business_clients_screen.dart';
import '../features/business/dashboard/business_dashboard_screen.dart';
import '../features/business/dashboard/business_scan_history_screen.dart';
import '../features/business/license/business_license_screen.dart';
import '../features/business/loyalty/business_create_loyalty_screen.dart';
import '../features/business/loyalty/business_loyalty_details_screen.dart';
import '../features/business/scanner/business_scanner_screen.dart';
import '../features/business/scanner/business_nfc_scanner_screen.dart';
import '../features/business/settings/business_profile_settings_screen.dart';
import '../features/business/setup/business_setup_screen.dart';
import '../features/business/settings/business_settings_screen.dart';
import '../features/business/subscriptions/business_subscription_details_screen.dart';
import '../features/business/subscriptions/business_create_subscription_screen.dart';
import '../features/client_wallet/cards/client_cards_screen.dart';
import '../features/client_wallet/cards/client_card_access_screen.dart';
import '../features/client_wallet/cards/client_card_details_screen.dart';
import '../features/client_wallet/dynamic_qr/client_dynamic_qr_screen.dart';
import '../features/client_wallet/import_card/client_import_card_screen.dart';
import '../features/client_wallet/manual_cards/client_manual_cards_screen.dart';
import '../features/client_wallet/settings/client_settings_screen.dart';
import '../features/client_wallet/wallet/client_wallet_screen.dart';
import '../features/onboarding/mode_selection_screen.dart';

GoRouter createAppRouter({
  required AppMode? selectedMode,
  required bool hasBusinessProfile,
}) {
  return GoRouter(
    initialLocation: _initialLocation(selectedMode, hasBusinessProfile),
    redirect: (context, state) {
      if (selectedMode == null) {
        return state.matchedLocation == RouteNames.modeSelection
            ? null
            : RouteNames.modeSelection;
      }

      if (state.matchedLocation == RouteNames.modeSelection) {
        return _modeHome(selectedMode, hasBusinessProfile);
      }

      if (selectedMode == AppMode.business && !hasBusinessProfile) {
        return state.matchedLocation == RouteNames.businessSetup
            ? null
            : RouteNames.businessSetup;
      }

      if (hasBusinessProfile &&
          state.matchedLocation == RouteNames.businessSetup) {
        return RouteNames.businessDashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.modeSelection,
        builder: (context, state) => const ModeSelectionScreen(),
      ),
      GoRoute(
        path: RouteNames.businessDashboard,
        builder: (context, state) => const BusinessDashboardScreen(),
      ),
      GoRoute(
        path: RouteNames.businessSetup,
        builder: (context, state) => const BusinessSetupScreen(),
      ),
      GoRoute(
        path: RouteNames.businessScanHistory,
        builder: (context, state) => const BusinessScanHistoryScreen(),
      ),
      GoRoute(
        path: RouteNames.businessClients,
        builder: (context, state) => const BusinessClientsScreen(),
      ),
      GoRoute(
        path: RouteNames.businessClientDetails,
        builder: (context, state) => BusinessClientDetailsScreen(
          customerId: state.pathParameters['customerId']!,
        ),
      ),
      GoRoute(
        path: RouteNames.businessCreateSubscription,
        builder: (context, state) => const BusinessCreateSubscriptionScreen(),
      ),
      GoRoute(
        path: RouteNames.businessSubscriptionDetails,
        builder: (context, state) => BusinessSubscriptionDetailsScreen(
          subscriptionId: state.pathParameters['subscriptionId']!,
        ),
      ),
      GoRoute(
        path: RouteNames.businessCreateLoyalty,
        builder: (context, state) => const BusinessCreateLoyaltyScreen(),
      ),
      GoRoute(
        path: RouteNames.businessLoyaltyDetails,
        builder: (context, state) => BusinessLoyaltyDetailsScreen(
          loyaltyId: state.pathParameters['loyaltyId']!,
        ),
      ),
      GoRoute(
        path: RouteNames.businessScanner,
        builder: (context, state) => const BusinessScannerScreen(),
      ),
      GoRoute(
        path: RouteNames.businessNfcScanner,
        builder: (context, state) => const BusinessNfcScannerScreen(),
      ),
      GoRoute(
        path: RouteNames.businessLicense,
        builder: (context, state) => const BusinessLicenseScreen(),
      ),
      GoRoute(
        path: RouteNames.businessBackup,
        builder: (context, state) => const BusinessBackupScreen(),
      ),
      GoRoute(
        path: RouteNames.businessSettings,
        builder: (context, state) => const BusinessSettingsScreen(),
      ),
      GoRoute(
        path: RouteNames.businessProfileSettings,
        builder: (context, state) => const BusinessProfileSettingsScreen(),
      ),
      GoRoute(
        path: RouteNames.clientWallet,
        builder: (context, state) => const ClientWalletScreen(),
      ),
      GoRoute(
        path: RouteNames.clientCards,
        builder: (context, state) => const ClientCardsScreen(),
      ),
      GoRoute(
        path: RouteNames.clientCardDetails,
        builder: (context, state) => ClientCardDetailsScreen(
          walletCardId: state.pathParameters['walletCardId']!,
        ),
      ),
      GoRoute(
        path: RouteNames.clientCardQrAccess,
        builder: (context, state) => ClientCardAccessScreen(
          walletCardId: state.pathParameters['walletCardId']!,
          mode: ClientCardAccessMode.qr,
        ),
      ),
      GoRoute(
        path: RouteNames.clientCardNfcAccess,
        builder: (context, state) => ClientCardAccessScreen(
          walletCardId: state.pathParameters['walletCardId']!,
          mode: ClientCardAccessMode.nfc,
        ),
      ),
      GoRoute(
        path: RouteNames.clientImportCard,
        builder: (context, state) => const ClientImportCardScreen(),
      ),
      GoRoute(
        path: RouteNames.clientDynamicQr,
        builder: (context, state) => const ClientDynamicQrScreen(),
      ),
      GoRoute(
        path: RouteNames.clientManualCards,
        builder: (context, state) => const ClientManualCardsScreen(),
      ),
      GoRoute(
        path: RouteNames.clientSettings,
        builder: (context, state) => const ClientSettingsScreen(),
      ),
    ],
  );
}

String _initialLocation(AppMode? selectedMode, bool hasBusinessProfile) {
  if (selectedMode == null) {
    return RouteNames.modeSelection;
  }

  return _modeHome(selectedMode, hasBusinessProfile);
}

String _modeHome(AppMode mode, bool hasBusinessProfile) {
  return switch (mode) {
    AppMode.business =>
      hasBusinessProfile
          ? RouteNames.businessDashboard
          : RouteNames.businessSetup,
    AppMode.client => RouteNames.clientWallet,
  };
}

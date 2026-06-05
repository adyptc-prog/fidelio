class RouteNames {
  const RouteNames._();

  static const modeSelection = '/';

  static const businessDashboard = '/business';
  static const businessSetup = '/business/setup';
  static const businessScanHistory = '/business/scan-history';
  static const businessClients = '/business/clients';
  static const businessClientDetails = '/business/clients/:customerId';
  static const businessSubscriptionDetails =
      '/business/subscriptions/:subscriptionId';
  static const businessCreateSubscription = '/business/subscriptions/create';
  static const businessCreateLoyalty = '/business/loyalty/create';
  static const businessLoyaltyDetails = '/business/loyalty/:loyaltyId';
  static const businessScanner = '/business/scanner';
  static const businessNfcScanner = '/business/nfc-scanner';
  static const businessLicense = '/business/license';
  static const businessBackup = '/business/backup';
  static const businessSettings = '/business/settings';
  static const businessProfileSettings = '/business/settings/profile';

  static const clientWallet = '/client';
  static const clientCards = '/client/cards';
  static const clientCardDetails = '/client/cards/:walletCardId';
  static const clientCardQrAccess = '/client/cards/:walletCardId/qr-access';
  static const clientCardNfcAccess = '/client/cards/:walletCardId/nfc-access';
  static const clientImportCard = '/client/import-card';
  static const clientDynamicQr = '/client/dynamic-qr';
  static const clientManualCards = '/client/manual-cards';
  static const clientSettings = '/client/settings';
}

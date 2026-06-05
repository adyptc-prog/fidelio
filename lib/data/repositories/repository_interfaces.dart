import '../../domain/entities/entities.dart';
import '../../domain/value_objects/app_mode.dart';

abstract interface class AppSettingsRepository {
  Future<AppSettings> loadSettings();

  Future<String?> loadClientWalletId();

  Future<void> saveClientWalletId(String walletId);

  Future<void> saveSelectedMode(AppMode mode);

  Future<void> clearSelectedMode();

  Future<void> saveClientCardsViewMode(ClientCardsViewMode mode);

  Future<void> saveBusinessClientsViewMode(BusinessClientsViewMode mode);

  Future<void> saveZoomMode(AppZoomMode mode);

  Future<void> saveDarkMode(bool enabled);
}

abstract interface class BusinessRepository {
  Future<BusinessProfile?> getActiveBusiness();

  Future<BusinessProfile?> getBusinessProfile(String businessId);

  Future<void> saveBusinessProfile(BusinessProfile profile);

  Future<void> deleteBusinessProfile(String businessId);
}

abstract interface class CustomerRepository {
  Future<List<CustomerRecord>> listCustomers(String businessId);

  Future<List<CustomerRecord>> searchCustomers(String businessId, String query);

  Future<CustomerRecord?> getCustomer(String customerId);

  Future<void> saveCustomer(CustomerRecord customer);

  Future<void> archiveCustomer(String customerId);

  Future<void> deleteCustomer(String customerId);
}

abstract interface class CardRepository {
  Future<List<SubscriptionCard>> listSubscriptionCards(String businessId);

  Future<List<SubscriptionCard>> listSubscriptionCardsForCustomer(
    String customerId,
  );

  Future<SubscriptionCard?> getSubscriptionCard(String cardId);

  Future<List<LoyaltyCard>> listLoyaltyCards(String businessId);

  Future<List<LoyaltyCard>> listLoyaltyCardsForCustomer(String customerId);

  Future<LoyaltyCard?> getLoyaltyCard(String cardId);

  Future<void> saveSubscriptionCard(SubscriptionCard card);

  Future<void> saveLoyaltyCard(LoyaltyCard card);

  Future<void> deleteSubscriptionCard(String cardId);

  Future<void> deleteLoyaltyCard(String cardId);
}

abstract interface class WalletRepository {
  Future<List<WalletCard>> listWalletCards(String walletId);

  Future<WalletCard?> getWalletCard(String walletCardId);

  Future<WalletCard?> getWalletCardByCardId({
    required String walletId,
    required String cardId,
  });

  Future<void> saveWalletCard(WalletCard card);

  Future<void> deleteWalletCard(String walletCardId);
}

abstract interface class CheckInRepository {
  Future<List<CheckInEvent>> listCheckIns(String businessId);

  Future<CheckInEvent?> getCheckIn(String eventId);

  Future<bool> hasValidCheckInForSignature({
    required String businessId,
    required String cardId,
    required String signature,
  });

  Future<void> saveCheckIn(CheckInEvent event);

  Future<void> deleteCheckIn(String eventId);
}

abstract interface class LoyaltyTransactionRepository {
  Future<List<LoyaltyTransaction>> listTransactions(String cardId);

  Future<LoyaltyTransaction?> getTransaction(String transactionId);

  Future<void> saveTransaction(LoyaltyTransaction transaction);

  Future<void> deleteTransaction(String transactionId);
}

abstract interface class LicenseRepository {
  Future<LicenseInfo?> getLicense(String licenseId);

  Future<List<LicenseInfo>> listLicenses(String businessId);

  Future<void> saveLicense(LicenseInfo license);

  Future<void> deleteLicense(String licenseId);
}

abstract interface class BackupRepository {
  Future<BackupInfo?> getBackup(String backupId);

  Future<List<BackupInfo>> listBackups(String? businessId);

  Future<void> saveBackup(BackupInfo backup);

  Future<void> deleteBackup(String backupId);
}

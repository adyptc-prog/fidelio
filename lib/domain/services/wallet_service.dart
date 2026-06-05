import '../entities/client_profile.dart';
import '../entities/wallet_card.dart';

abstract interface class WalletService {
  Future<ClientProfile> createLocalWallet({String? displayName});

  Future<ClientProfile?> getCurrentClientProfile();

  Future<List<WalletCard>> getWalletCards();

  Future<void> importWalletCard(WalletCard card);
}

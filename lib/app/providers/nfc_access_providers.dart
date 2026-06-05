import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/android_nfc_access_service.dart';
import '../../domain/services/nfc_access_service.dart';

final nfcAccessServiceProvider = Provider<NfcAccessService>((ref) {
  return const AndroidNfcAccessService();
});

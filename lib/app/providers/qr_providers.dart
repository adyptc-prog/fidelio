import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/local_qr_service.dart';
import '../../domain/services/qr_service.dart';

final qrServiceProvider = Provider<QrService>((ref) {
  return const LocalQrService();
});

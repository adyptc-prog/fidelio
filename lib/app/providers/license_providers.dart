import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/android_usb_license_service.dart';
import '../../domain/entities/license_status.dart';

final usbLicenseServiceProvider = Provider<AndroidUsbLicenseService>((ref) {
  return const AndroidUsbLicenseService();
});

final businessLicenseStatusProvider =
    FutureProvider.family<LicenseStatus, String>((ref, businessId) {
      return ref.watch(usbLicenseServiceProvider).checkLicense(businessId);
    });

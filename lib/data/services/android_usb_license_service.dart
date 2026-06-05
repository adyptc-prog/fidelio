import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/entities/license_status.dart';

class AndroidUsbLicenseService {
  const AndroidUsbLicenseService();

  static const _channel = MethodChannel('fidelio/license');

  Future<LicenseStatus> checkLicense(String businessId) async {
    if (!Platform.isAndroid) {
      return const LicenseStatus(
        state: LicenseState.missing,
        message: 'USB license detection is available only on Android.',
      );
    }

    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'checkLicense',
      {'businessId': businessId},
    );
    if (result == null) {
      return const LicenseStatus(
        state: LicenseState.missing,
        message: 'USB license was not found.',
      );
    }
    return LicenseStatus.fromJson(result);
  }

  Future<void> pickLicenseFile() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<String>('pickLicenseFile');
  }
}

import '../entities/license_info.dart';

abstract interface class LicenseService {
  Future<LicenseInfo?> getActiveLicense();

  Future<LicenseInfo> importSignedLicenseFile(String filePath);

  Future<bool> validateLicense(LicenseInfo license);
}

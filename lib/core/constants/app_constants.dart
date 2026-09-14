class AppConstants {
  const AppConstants._();

  static const databaseName = 'local_loyalty.sqlite';
  static const licenseFileExtension = '.local-loyalty-license';
  static const backupFileExtension = '.local-loyalty-backup';

  /// Keep in sync with the `version:` field in pubspec.yaml.
  static const appVersion = '1.0.2';
  static const appVersionLabel = 'v$appVersion';

  static const appTagline = 'Fidelio by Volt Academy';
  static const appWebsite = 'voltacademy.app';
}

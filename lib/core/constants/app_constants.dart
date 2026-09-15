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

  /// Default text a client can send to a business to suggest they adopt
  /// Fidelio, via the share sheet or copied as a review. Editable by the
  /// client before sending.
  static const recommendationText =
      "I'm using Fidelio, a customer loyalty card app, at other "
      'businesses, and I would love to use it at yours too. The app is '
      'available at $appWebsite.';
}

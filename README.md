# Fidelio Local Loyalty

Fidelio is a local-first Flutter application for small businesses that need
membership cards, loyalty cards, QR/NFC check-in, USB licensing, and USB backup
without server accounts.

## Core Modes

### Business Mode

- Create and manage customers.
- Issue memberships and loyalty cards.
- Scan customer QR/NFC access codes.
- Track recent check-ins.
- Configure business profile, card colors, and app display settings.
- Create and restore local USB backups.
- Check USB-C lifetime license status.

### Client Mode

- Import cards received from a business by QR or NFC.
- View wallet cards in list or grid mode.
- Generate QR or NFC access for a selected card.
- Update the local wallet card after the business scans the access code.

## Free Limit And License

The app allows 10 free memberships/loyalty cards per business. After that limit,
new cards require a valid USB-C license.

License support contact:

```text
voltacademy007@gmail.com
```

On Android, place the license file on the USB-C stick at:

```text
/Fidelio/fidelio_license.json
```

The license screen can check again or select the license file manually.

## QR And NFC Flow

Business-issued cards can be shared with the client by QR or NFC. The client can
then open a card, generate QR/NFC access, and show or present it to the business.
The business scanner validates the dynamic access payload locally and prevents
reused valid QR/NFC codes.

After a successful scan, the client can tap `Update local card` to decrement the
local wallet copy on the phone. The business database remains the source of truth
for business-side check-ins.

## Backup And Restore

Business mode supports USB backup and restore on Android. Restoring a backup
replaces local data with the selected backup and reloads the app providers after
restore.

## Development

Install Flutter, then run:

```bash
flutter pub get
flutter test
```

Run static analysis:

```bash
dart analyze lib test
```

Important test areas:

- `test/local_qr_service_test.dart`
- `test/business_check_in_controller_test.dart`
- `test/local_database_repositories_test.dart`
- `test/widget_test.dart`

## Platform Notes

QR functionality is pure Flutter. NFC, USB license detection, and USB backup are
implemented through Android platform channels and are available only on Android.

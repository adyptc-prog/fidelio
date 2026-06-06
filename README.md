# Fidelio

**Local loyalty and membership management for small businesses.**
No server. No internet. No accounts.

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Flutter](https://img.shields.io/badge/Flutter-3.10%2B-02569B?logo=flutter)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-7.0%2B-3DDC84?logo=android)](https://www.android.com)

---

## What is Fidelio?

Fidelio is a free, open-source Flutter app that lets small businesses manage loyalty cards and memberships entirely on-device — no server, no subscription, no internet connection required.

Works for coffee shops, salons, restaurants, delivery services, gyms, and any business that wants to reward loyal customers.

---

## Features

### Business Mode
- Create and manage customers
- Issue **membership cards** (with expiry dates and entry counts)
- Issue **loyalty cards** — stamps, points, visit challenges, delivery
- Validate access via **QR scan** or **NFC** (Android)
- View full check-in history
- **Daily automatic USB backup**
- USB-C lifetime license for unlimited cards

### Client Mode
- Import cards by scanning a business QR code or via NFC
- Wallet view in list or grid
- Generate a **dynamic QR or NFC access code** for any card
- Update card locally after each visit

---

## How It Works

```
Business creates card  →  shares via QR/NFC
Client imports card    →  generates dynamic access code
Business scans code    →  validates locally, updates card
```

All validation happens on-device. QR codes are time-limited and signed with HMAC-SHA256. NFC uses Android HCE (Host Card Emulation). Replay attacks are prevented by a unique index on each signature.

---

## Free Tier & License

| Cards per business | Requirement |
|---|---|
| Up to 10 | Free forever |
| Unlimited | USB-C lifetime license |

To issue a license, place `fidelio_license.json` on a USB-C stick at `/Fidelio/fidelio_license.json`. The app detects it automatically on Android.

License inquiries: **adyptc@gmail.com**

---

## Platform Support

| Feature | Android | iOS |
|---|---|---|
| QR scan & generate | ✅ | ✅ |
| NFC access | ✅ | ❌ |
| USB backup | ✅ | ❌ |
| USB license | ✅ | ❌ |

NFC and USB features use Android platform channels and are not available on iOS.

---

## Getting Started

### Requirements
- Flutter SDK 3.10+
- Android SDK (minSdk 24 — Android 7.0)

### Run

```bash
git clone https://github.com/adyptc-prog/fidelio.git
cd fidelio
flutter pub get
flutter run
```

### Test

```bash
flutter test
dart analyze
```

### Build release APK

```bash
flutter build apk --release
```

---

## Architecture

Clean architecture with three layers:

```
lib/
  domain/       # Entities, service interfaces, value objects
  data/         # Drift/SQLite repositories, Android services
  features/     # UI screens per feature
  app/          # Riverpod providers, router, theme
```

- **State management:** Riverpod (`AsyncNotifierProvider`)
- **Navigation:** GoRouter
- **Database:** Drift (SQLite, local-only)
- **QR:** `mobile_scanner` + `qr_flutter`

---

## Contributing

Pull requests are welcome. For major changes, open an issue first.

All contributions must be compatible with the AGPL-3.0 license.

---

## License

This project is licensed under the **GNU Affero General Public License v3.0**.
See [LICENSE](LICENSE) for details.

© 2026 Fidelio Contributors

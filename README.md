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
- Unlimited cards with an activation license (see [Free Tier & Activation License](#free-tier--activation-license))

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

## Free Tier & Activation License

The complete source code — including the 10-card free limit — is published here under the AGPL-3.0.
**The code is not sold**, and the rights the AGPL gives you (to use, study, modify and redistribute it)
don't depend on buying anything.

What is sold is an **activation license**: a signed file, tied to one Business ID, that unlocks the
10-card limit in the Fidelio business app distributed by Volt Academy (the Android APK available at
[voltacademy.app/fidelio.html](https://voltacademy.app/fidelio.html)).

| Cards per business | Requirement |
|---|---|
| Up to 10 | Free |
| Unlimited | Activation license — 30, 60 or 180 days, or permanent |

Licenses are bought at [voltacademy.app/fidelio.html](https://voltacademy.app/fidelio.html#licentiere),
where current prices are listed. Expirable licenses bought for the same Business ID add up, and the
license becomes permanent automatically once their total reaches the price of a permanent license.

To activate a license:

1. Open the **License** screen in the app and copy your Business ID.
2. Buy a license on the site with that Business ID and download `fidelio_license.json`.
3. Back on the License screen, tap **Select License File** and pick the file from your phone storage
   or from a USB-C stick. A file placed at `/Fidelio/fidelio_license.json` on a USB-C stick is also
   detected automatically.

The Fidelio client wallet apps on the App Store and Google Play are free and don't need a license.

Questions about licenses: [voltacademy.app/contact.html](https://voltacademy.app/contact.html)

---

## Platform Support

| Feature | Android | iOS |
|---|---|---|
| QR scan & generate | ✅ | ✅ |
| NFC access | ✅ | ❌ |
| USB backup | ✅ | ❌ |
| License import (file or USB) | ✅ | ❌ |

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

## Author

**Adrian Petcu** — [Volt Academy](mailto:adyptc@gmail.com)

---

## Contributing

Pull requests are welcome. For major changes, open an issue first.

All contributions must be compatible with the AGPL-3.0 license.

---

## License

**Fidelio — Local Loyalty & Membership App**<br>
Copyright (C) 2026 Adrian Petcu — Volt Academy

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Affero General Public License for more details.

The full text of the **GNU Affero General Public License v3.0** is in [LICENSE](LICENSE).

SPDX-License-Identifier: AGPL-3.0-or-later

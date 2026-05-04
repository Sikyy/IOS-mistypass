# App Store Submission Checklist

## App Information

- **App Name:** Mistyislet
- **Subtitle:** Mobile Access Control
- **Bundle ID:** com.mistyislet.pass
- **Category:** Business (Primary), Utilities (Secondary)
- **Content Rating:** 4+
- **Price:** Free

## Description (English)

Mistyislet is a mobile access control app for the Indonesian SaaS access control platform. Unlock doors with your phone using BLE, QR codes, or NFC cards.

Key Features:
- BLE Auto-Unlock: Walk up to a door and unlock with a long press. Secure Enclave ECDSA authentication.
- QR Pass: Display a dynamic QR code for door readers to scan.
- NFC Card Binding: Register your physical DESFire EV3 card for tap-to-open.
- Visitor Management: Create temporary visitor passes with QR codes.
- Offline Mode: BLE unlock works without internet for up to 72 hours.
- Lock Screen Widget: Quick access to your favorite door from the Lock Screen.
- Multi-Site: Switch between buildings and locations.
- Biometric Lock: Face ID / Touch ID before every unlock for extra security.

## Description (Bahasa Indonesia)

Mistyislet adalah aplikasi kontrol akses mobile untuk platform kontrol akses SaaS Indonesia. Buka pintu dengan ponsel Anda menggunakan BLE, kode QR, atau kartu NFC.

## Keywords

access control, door unlock, BLE, NFC, QR code, smart lock, building access, visitor management, security

## Screenshots Required (iPhone 17 Pro: 1320 x 2868 px)

1. **Doors List** — Home screen showing door list with status indicators
2. **Hold to Unlock** — Door card with hold-to-unlock progress animation
3. **Unlock Success** — Green overlay showing "Door Unlocked"
4. **QR Pass** — Full screen QR code display for door reader
5. **Visitor Pass** — Visitor QR code with share button
6. **Profile** — Settings screen with credentials and biometric toggle

## App Review Notes

This app requires a backend server to function. For review purposes:
- Test account: review@mistyislet.com / [provided separately]
- The BLE unlock feature requires physical door controller hardware. Remote unlock via HTTPS is available for testing.
- NFC card binding requires a physical DESFire EV3 card.
- Location permission is optional (for geofence auto-unlock only).

## Privacy Policy URL

https://mistyislet.com/privacy

## Support URL

https://mistyislet.com/support

## Required Capabilities

- bluetooth-le (BLE door unlock)
- nfc (NFC card binding)
- arm64

## Entitlements

- Keychain Access Groups
- App Groups (shared with Widget)
- NFC Tag Reading
- Push Notifications (APNs)

## Pre-Submission Checklist

- [ ] Set DEVELOPMENT_TEAM in project.yml
- [ ] Add App Icon (1024x1024) to Assets.xcassets
- [ ] Configure App Store Connect app record
- [ ] Upload screenshots for iPhone 17 Pro (1320x2868)
- [ ] Set privacy policy URL
- [ ] Configure push notification certificate in Apple Developer Portal
- [ ] Create App Group "group.com.mistyislet.pass" in Developer Portal
- [ ] Enable NFC Tag Reading capability in Developer Portal
- [ ] Test on physical iPhone 17 Pro device
- [ ] Run full test suite
- [ ] Archive and upload via Xcode or fastlane

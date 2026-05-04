# Mistyislet iOS App — Development Plan v2

> Updated: 2026-05-03
> Architecture baseline: `Indonesia_SaaS_Access_Control_Architecture.md` v2
> Design baseline: Apple Human Interface Guidelines (HIG) + iOS 18/26
> Competitive baseline: Kisi iOS App feature set
> Detailed API/code spec: see `IOS-APP-DEVELOPMENT.md` (existing, complementary)

---

## 1. Product Vision

Mistyislet iOS App is a **resident-facing mobile access** application for the Indonesian SaaS access control platform. It is NOT an admin console.

**Core user story:** A worker walks toward a door, the phone auto-discovers the Controller via BLE, authenticates with a hardware-backed private key, and the door opens — all in < 300ms, even when offline.

### 1.1 V2 Architecture Alignment — Three-Tier Credential Support

| Tier | Credential | iOS Implementation | Priority |
|------|-----------|-------------------|----------|
| Tier 1 | BLE mobile credential | Secure Enclave EC P-256 + Core Bluetooth GATT Client | Phase 1 |
| Tier 2 | DESFire EV3 physical card | Core NFC Tag Reading (self-service card binding) | Phase 2 |
| Tier 3 | Dynamic QR code | AVFoundation camera scan + short-lived token | Phase 1 |

### 1.2 Kisi Feature Parity Matrix

| Kisi iOS Feature | Mistyislet | Priority | Notes |
|-----------------|-----------|----------|-------|
| Door list with status | Yes | P0 | Gateway online/offline indicator |
| Tap-to-unlock (BLE) | Yes | P0 | Auto-discover + challenge-response |
| Remote unlock | Yes | P0 | HTTPS → Cloud → Controller |
| Apple Wallet Pass | Deferred | P3 | Apple Pay not available in Indonesia |
| QR code scan unlock | Yes | P0 | AVFoundation camera |
| Access history timeline | Yes | P1 | Paginated + pull-to-refresh |
| Visitor pass creation | Yes | P1 | QR token + expiry + door selection |
| Widget (Lock Screen) | Yes | P2 | WidgetKit quick-unlock |
| Auto-unlock geofence | Partial | P3 | Core Location region monitoring |
| Credential management | Yes | P1 | View/revoke registered devices |
| Multi-site switching | Yes | P2 | Tenant/building picker |
| Offline mode | Yes | P0 | BLE auth works without internet |
| Biometric gate | Yes | P1 | Face ID / Touch ID before unlock |
| Push notifications | Yes | P1 | APNs for permission changes, door events |
| Share access link | Yes | P2 | Deep link to visitor QR |

---

## 2. Design Language — Apple HIG Compliance

### 2.1 Core Principles (from HIG)

| HIG Principle | Application in Mistyislet |
|--------------|--------------------------|
| **Clarity** | Door names, status, and unlock result must be immediately legible in all lighting |
| **Deference** | Content-first: the door list IS the interface, not chrome around it |
| **Depth** | Use sheet presentations for unlock details, full-screen for QR scanner |
| **Consistency** | Follow iOS navigation patterns — Tab Bar (5 tabs max), NavigationStack push |
| **Direct manipulation** | Long-press a door to unlock; swipe for quick actions |
| **Feedback** | Haptic (UIImpactFeedbackGenerator) + visual + audio on every unlock attempt |

### 2.2 Tab Structure (5 tabs)

```
Tab Bar (always visible)
├── Doors        (house.fill)        — Primary: door list + BLE unlock
├── Scanner      (qrcode.viewfinder) — QR code scan unlock
├── History      (clock.arrow.circlepath) — Access event timeline
├── Visitors     (person.badge.plus) — Create/manage visitor passes
└── Profile      (person.crop.circle) — Credentials, settings, logout
```

### 2.3 Color System

| Role | Light Mode | Dark Mode | Usage |
|------|-----------|-----------|-------|
| Brand Primary | #4F55FF | #8589FF | Tab bar active, buttons, links |
| Success | systemGreen | systemGreen | Access granted, door unlocked |
| Denied | systemRed | systemRed | Access denied, expired credential |
| Warning | systemOrange | systemOrange | Offline, credential expiring |
| Background | systemBackground | systemBackground | HIG-compliant adaptive |
| Surface | secondarySystemBackground | secondarySystemBackground | Cards, sheets |
| Label | label | label | Primary text |
| SecondaryLabel | secondaryLabel | secondaryLabel | Subtitles, metadata |

**Important:** Use semantic colors from UIKit/SwiftUI (`Color.primary`, `Color.secondary`, `.background`) — never hardcode hex values for backgrounds. Only brand accent uses fixed color.

### 2.4 Typography (SF Pro via Dynamic Type)

| Style | Usage | HIG Mapping |
|-------|-------|-------------|
| .largeTitle | Screen titles | Large Title |
| .title2 | Section headers | Title 2 |
| .headline | Door names, card titles | Headline |
| .body | Door details, descriptions | Body |
| .callout | Status badges, metadata | Callout |
| .caption | Timestamps, expiry info | Caption 1 |
| .caption2 | Fine print | Caption 2 |

**Mandatory:** Support Dynamic Type at all sizes. Use `@ScaledMetric` for custom spacing. Test with Accessibility Inspector at xxxLarge.

### 2.5 SF Symbols Usage

| Context | Symbol | Weight |
|---------|--------|--------|
| Door (locked) | lock.fill | medium |
| Door (unlocked) | lock.open.fill | medium |
| BLE connecting | dot.radiowaves.left.and.right | medium |
| BLE success | checkmark.circle.fill | medium |
| Gateway online | circle.fill (green) | light |
| Gateway offline | circle.fill (gray) | light |
| Unlock button | lock.open.trianglebadge.exclamationmark | bold |
| QR scanner | qrcode.viewfinder | medium |
| Visitor | person.badge.plus | medium |
| History | clock.arrow.circlepath | medium |
| Credential | key.fill | medium |
| Settings | gearshape | medium |

---

## 3. Screen-by-Screen Design Specification

### 3.1 Doors Screen (Home Tab)

**Layout:** NavigationStack with large title "Doors"

```
┌─────────────────────────────────┐
│ Doors                    [Sort] │  ← Large Title + sort button
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ 🟢 Main Entrance            │ │  ← Online indicator + door name
│ │    Lobby · Floor 1           │ │  ← Building + floor
│ │    [Hold to Unlock]          │ │  ← Contextual CTA
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ 🔴 Server Room              │ │  ← Offline indicator
│ │    Data Center · B2          │ │
│ │    Controller offline        │ │  ← Status message
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ 🟡 Parking Gate             │ │  ← Degraded
│ │    Parking · G               │ │
│ │    [Hold to Unlock]          │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

**Interaction — Hold to Unlock (HIG: Direct Manipulation)**
1. User long-presses door card (0.5s minimum hold)
2. Circular progress animation fills during hold
3. On release after fill: trigger BLE unlock sequence
4. Haptic: `.impact(.medium)` on hold start, `.notification(.success)` on granted
5. Full-screen overlay shows result for 2 seconds:
   - **Granted**: Green checkmark + door name + haptic success
   - **Denied**: Red X + reason text + haptic error

**BLE Auto-Discover (Background)**
- Core Bluetooth `CBCentralManager` scans for `4d495354-5950-4153-532d-424c45415554` service UUID
- When discovered, show "BLE Ready" indicator on the door card
- User can also tap "Unlock" button directly (triggers connect → auth → unlock)

### 3.2 QR Scanner Screen

**Layout:** Full-screen camera with overlay

```
┌─────────────────────────────────┐
│         [Close]                 │
│                                 │
│      ┌───────────────┐          │
│      │               │          │
│      │   QR Viewfinder│          │
│      │   (animated)   │          │
│      │               │          │
│      └───────────────┘          │
│                                 │
│   Point camera at QR code       │
│   to unlock the door            │
│                                 │
│      💡 [Toggle Flash]          │
└─────────────────────────────────┘
```

- AVFoundation `AVCaptureSession` with `AVMetadataObject.ObjectType.qr`
- Auto-dismiss on successful scan
- Debounce: ignore duplicate scans within 3 seconds
- Error state: "Invalid QR code" with shake animation

### 3.3 Unlock Feedback Overlay (HIG: Feedback)

**Success State:**
```
┌─────────────────────────────────┐
│                                 │
│           ✅                     │
│      Door Unlocked              │
│      Main Entrance              │
│      10:23 AM                   │
│                                 │
│   Auto-dismiss in 2s            │
└─────────────────────────────────┘
```
- Background: translucent green overlay
- Haptic: `UINotificationFeedbackGenerator.success`
- Sound: system unlock sound (optional, respecting silent mode)

**Failure State:**
```
┌─────────────────────────────────┐
│                                 │
│           ❌                     │
│      Access Denied              │
│      No permission for          │
│      this door                  │
│                                 │
│      [Try Again]  [Dismiss]     │
└─────────────────────────────────┘
```
- Background: translucent red overlay
- Haptic: `UINotificationFeedbackGenerator.error`

**Loading State:**
```
┌─────────────────────────────────┐
│                                 │
│        ◠ ◡ (BLE pulse)          │
│      Connecting...              │
│      Main Entrance              │
│                                 │
└─────────────────────────────────┘
```
- Custom BLE radio wave animation (SF Symbol: `dot.radiowaves.left.and.right`)
- Timeout: 5 seconds → show "Connection failed, try again"

### 3.4 History Screen

**Layout:** List with date sections

```
┌─────────────────────────────────┐
│ History                         │
├─────────────────────────────────┤
│ TODAY                           │
│ ┌─────────────────────────────┐ │
│ │ ✅ Main Entrance    10:23   │ │
│ │ ✅ Parking Gate     08:15   │ │
│ │ ❌ Server Room      08:14   │ │
│ └─────────────────────────────┘ │
│ YESTERDAY                       │
│ ┌─────────────────────────────┐ │
│ │ ✅ Main Entrance    18:30   │ │
│ │ ✅ Main Entrance    08:05   │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

- Pull-to-refresh
- Infinite scroll with pagination
- Tap row → detail sheet with event metadata

### 3.5 Visitors Screen

**Layout:** List + Create FAB

```
┌─────────────────────────────────┐
│ Visitors               [+ New]  │
├─────────────────────────────────┤
│ ACTIVE PASSES                   │
│ ┌─────────────────────────────┐ │
│ │ John Doe                    │ │
│ │ Acme Corp · Meeting         │ │
│ │ Expires in 22h  [QR] [Copy] │ │
│ └─────────────────────────────┘ │
│ EXPIRED                         │
│ ┌─────────────────────────────┐ │
│ │ Jane Smith   (expired)      │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

**Create Visitor Sheet:**
- Name (required), Phone (required), Host (required)
- Door selection (multi-select picker)
- TTL picker: 4h / 8h / 24h / 48h / 72h
- On create → show QR code full-screen with share button

**QR Display:**
- Generate QR from `access_token` using `CIFilter("CIQRCodeGenerator")`
- Share button: `UIActivityViewController` with QR image + text link
- Copy token button

### 3.6 Profile Screen

```
┌─────────────────────────────────┐
│ Profile                         │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ 👤 user@example.com         │ │
│ │    Jakarta HQ · Employee    │ │
│ └─────────────────────────────┘ │
│                                 │
│ MY CREDENTIALS                  │
│ ┌─────────────────────────────┐ │
│ │ 📱 This iPhone              │ │
│ │    Secure Enclave · Active  │ │
│ │    Expires: Jul 30, 2026    │ │
│ │                    [Revoke] │ │
│ └─────────────────────────────┘ │
│                                 │
│ SETTINGS                        │
│ ┌─────────────────────────────┐ │
│ │ Language          English ▸ │ │
│ │ Biometric Lock    On     ▸ │ │
│ │ Notifications     On     ▸ │ │
│ │ About                    ▸ │ │
│ └─────────────────────────────┘ │
│                                 │
│      [Sign Out]                 │
└─────────────────────────────────┘
```

---

## 4. BLE Authentication Flow — iOS Implementation

### 4.1 Core Bluetooth Architecture

```
CBCentralManager (background scan)
    │ discovers service UUID 4d495354-5950-4153-532d-424c45415554
    ▼
CBPeripheral.connect()
    │ on didConnect
    ▼
discoverServices([mistypassServiceUUID])
    │
    ├── Read CONTROLLER_IDENTITY → verify certificate chain (optional Phase 2)
    │
    ├── Read CHALLENGE → receive [32B nonce][8B issued_at][8B expires_at]
    │
    ├── Sign: SecKeyCreateSignature(.ecdsaSignatureMessageX962SHA256, privateKey, SHA256(nonce || userID))
    │
    ├── Write AUTH_RESPONSE → [1B userID_len][userID][signature]
    │
    └── Subscribe AUTH_RESULT (Notify) → [1B code][reason string]
            0x01 = Granted → haptic + unlock animation
            0x02 = Denied → haptic + error
```

### 4.2 Secure Enclave Key Management

```swift
// Generate EC P-256 key in Secure Enclave
let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    [.privateKeyUsage],  // biometric gate: add .userPresence
    nil
)!

let attributes: [String: Any] = [
    kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
    kSecAttrKeySizeInBits: 256,
    kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,  // hardware-backed
    kSecPrivateKeyAttrs: [
        kSecAttrIsPermanent: true,
        kSecAttrApplicationTag: "com.mistyislet.credential".data(using: .utf8)!,
        kSecAttrAccessControl: access,
    ]
]

var error: Unmanaged<CFError>?
guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
    // fallback: remove kSecAttrTokenID for older devices (software keychain)
}
let publicKey = SecKeyCopyPublicKey(privateKey)!
// Export public key as DER → base64 → PEM → POST /app/credentials/register
```

### 4.3 Background BLE Scanning (HIG: Background Execution)

```swift
// Info.plist
UIBackgroundModes: ["bluetooth-central"]
NSBluetoothAlwaysUsageDescription: "Mistyislet uses Bluetooth to unlock doors near you."

// State restoration
centralManager = CBCentralManager(
    delegate: self,
    queue: bleQueue,
    options: [CBCentralManagerOptionRestoreIdentifierKey: "mistyislet-ble"]
)

// Scan with service UUID filter (required for background)
centralManager.scanForPeripherals(
    withServices: [mistypassServiceUUID],
    options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
)
```

---

## 5. Accessibility (HIG + WCAG 2.2)

### 5.1 Critical Requirements for Access Control App

| Requirement | Implementation | HIG Reference |
|------------|---------------|---------------|
| **VoiceOver** | All door cards, buttons, and status indicators fully labeled | Accessibility > VoiceOver |
| **Dynamic Type** | All text scales from xSmall to xxxLarge | Typography > Dynamic Type |
| **Reduce Motion** | Replace animations with fade transitions when enabled | Motion > Reduce Motion |
| **High Contrast** | Use `.accessibilityLabel` with status descriptions, not just color | Color and Effects |
| **Switch Control** | All interactive elements reachable via switch | Motor > Switch Control |
| **Voice Control** | All buttons have stable accessibility labels for voice commands | Motor > Voice Control |
| **Haptic fallback** | Visual+audio feedback for users who cannot feel haptics | Feedback |
| **Large touch targets** | Minimum 44x44pt for all tappable elements (HIG minimum) | Layout > Hit Targets |
| **Dark environment** | Door unlock works in dark hallways (high contrast unlock overlay) | — |
| **Hands occupied** | Auto-unlock (BLE proximity) doesn't require hand interaction | — |

### 5.2 VoiceOver Labels

```swift
// Door card
.accessibilityLabel("Main Entrance, Floor 1, Lobby, Controller online")
.accessibilityHint("Long press to unlock")
.accessibilityValue(isUnlocking ? "Unlocking..." : "Ready")

// Unlock result
.accessibilityLabel(granted ? "Access granted for Main Entrance" : "Access denied: \(reason)")

// QR code
.accessibilityLabel("QR access code for visitor \(name), expires in \(timeRemaining)")
```

---

## 6. Offline Mode (V2 Architecture: 72h Offline)

| Scenario | Behavior |
|----------|----------|
| Phone has internet, Controller online | Normal flow: BLE auth → Controller verify → unlock |
| Phone has internet, Controller offline | Remote unlock via cloud (if Controller has cached rules) |
| Phone offline, Controller online | BLE auth still works (key is local, Controller verifies locally) |
| Both offline | BLE auth still works if Controller has cached public key (< 72h) |
| Credential expired + offline | Deny; user must reconnect to refresh credential |

**Local caching strategy:**
- Cache door list in SwiftData/Core Data for instant display
- Cache credential metadata (expiry, status) locally
- Show clear "Offline" banner with last sync timestamp

---

## 7. Push Notifications (APNs)

| Event | Notification | Action |
|-------|-------------|--------|
| Permission granted for new door | "You now have access to Server Room" | Open door detail |
| Permission revoked | "Your access to Server Room has been removed" | Open doors list |
| Credential expiring (< 24h) | "Your access credential expires tomorrow" | Open profile > renew |
| Credential revoked | "Your device credential has been revoked" | Open profile |
| Visitor checked in | "Your visitor John Doe has arrived" | Open visitors |
| Door held open alert | "Main Entrance held open for > 30s" | Open door detail |

---

## 8. Development Phases

### Phase 1 — MVP (6-8 weeks)

| # | Feature | Effort | Deliverable |
|---|---------|--------|-------------|
| 1 | Project setup (SwiftUI + SPM + CI) | 2d | Xcode project, build pipeline |
| 2 | Login + JWT token management | 3d | Login screen, Keychain token store, auto-refresh |
| 3 | Door list + pull-to-refresh | 3d | Doors tab with gateway status |
| 4 | BLE unlock (Core Bluetooth GATT client) | 5d | Challenge-response flow, Secure Enclave signing |
| 5 | Credential registration (Secure Enclave key → API) | 3d | Auto-register on first launch |
| 6 | Remote unlock (HTTPS fallback) | 2d | "Hold to Unlock" with cloud path |
| 7 | QR scanner + unlock | 3d | AVFoundation camera, token validation |
| 8 | Unlock feedback overlay (haptic + visual) | 2d | Success/denied/loading states |
| 9 | Offline mode (local cache) | 2d | SwiftData door cache, offline banner |
| 10 | Dark mode + accessibility pass | 2d | Dynamic Type, VoiceOver, contrast |

### Phase 2 — Feature Complete (4-6 weeks)

| # | Feature | Effort |
|---|---------|--------|
| 11 | Access history timeline | 3d |
| 12 | Visitor pass creation + QR display | 4d |
| 13 | Credential management (view/revoke) | 2d |
| 14 | Push notifications (APNs) | 3d |
| 15 | Face ID / Touch ID gate | 2d |
| 16 | Profile + settings (language, biometric toggle) | 2d |
| 17 | NFC card binding (Core NFC) | 3d |
| 18 | Multi-site switching | 2d |
| 19 | Indonesian localization (id-ID) | 2d |

### Phase 3 — Polish (2-4 weeks)

| # | Feature | Effort |
|---|---------|--------|
| 20 | Lock Screen Widget (WidgetKit) | 3d |
| 21 | Apple Wallet Pass integration (when available) | 5d |
| 22 | Geofence auto-unlock (Core Location) | 3d |
| 23 | Share visitor link (UIActivityViewController) | 1d |
| 24 | App Store submission + review | 3d |

---

## 9. Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Crypto key | Secure Enclave EC P-256 | Hardware-backed, matches Android Keystore |
| BLE library | Core Bluetooth (native) | Only option on iOS, well-documented |
| Minimum iOS | 16.0 | NavigationStack, SwiftUI maturity |
| Architecture | MVVM + Repository | SwiftUI native, Observable macro |
| Storage | SwiftData | Apple-native, lightweight |
| Network | URLSession + async/await | No dependencies, Swift concurrency |
| QR generation | CIFilter("CIQRCodeGenerator") | Built-in, no external library |
| Haptics | UIFeedbackGenerator | HIG standard |

---

## 10. Risk Register

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Secure Enclave not available on old devices | Fallback to software Keychain | Detect with `kSecAttrTokenIDSecureEnclave` availability |
| BLE background scanning killed by iOS | User must open app | Background mode + state restoration + foreground service hint |
| Core NFC limited on iOS | Cannot write NFC tags | Read-only card binding is sufficient |
| Apple Wallet not available in Indonesia | No NFC tap-to-open | BLE is primary; Wallet is bonus |
| App Store review rejection | Delayed launch | Pre-submission review with Apple, clear privacy description |

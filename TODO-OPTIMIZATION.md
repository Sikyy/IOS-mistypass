# Mistyislet iOS App — Pending Optimization Items

> Generated: 2026-05-03
> Status: All items are non-blocking. App compiles and runs, but these should be addressed before App Store submission.

---

## P0 — Functional Bugs (Must Fix)

### 1. DoorsViewModel.biometricEnabled not wired to SettingsService
- **File:** `MistyisletPass/ViewModels/DoorsViewModel.swift:13`
- **Problem:** `var biometricEnabled = true` is a hardcoded local property. Toggling biometric lock in Profile Settings has no effect on the unlock flow.
- **Fix:** Replace with `SettingsService.shared.biometricEnabled` read:
  ```swift
  private var biometricEnabled: Bool { SettingsService.shared.biometricEnabled }
  ```

### 2. GeofenceSettingsView — geofence enabled key bypasses SettingsService
- **File:** `MistyisletPass/Views/Profile/GeofenceSettingsView.swift:19,65`
- **Problem:** `"settings.geofenceEnabled"` is read/written via `UserDefaults.standard` directly, not through `SettingsService`. Not observable from other parts of the app.
- **Fix:** Add `geofenceEnabled` property to `SettingsService` with stored + didSet pattern.

---

## P1 — Swift 6 Strict Concurrency

### 3. BLEManager — Missing @MainActor + inconsistent delegate dispatch
- **File:** `MistyisletPass/Services/BLEManager.swift`
- **Problem:** `@Observable` class with no actor isolation. CBDelegate callbacks fire on `bleQueue` and mutate observable properties. Some use `DispatchQueue.main.async`, some don't. `authResultContinuation` has a data race between timeout and delegate callbacks.
- **Fix:**
  - Add `@MainActor` to BLEManager
  - Replace all `DispatchQueue.main.async` with `Task { @MainActor in }`
  - Protect `authResultContinuation` with an `NSLock` or serialize via a dedicated `Task`

### 4. APIService — isRefreshing race condition
- **File:** `MistyisletPass/Services/APIService.swift:28,171`
- **Problem:** `isRefreshing` is a plain `var` with no isolation. Two concurrent 401 responses can both pass the `!isRefreshing` check and issue duplicate refresh requests.
- **Fix:** Deduplicate with a shared `Task`:
  ```swift
  private var refreshTask: Task<Bool, Never>?
  private func attemptTokenRefresh() async -> Bool {
      if let existing = refreshTask { return await existing.value }
      let task = Task<Bool, Never> { /* refresh logic */ }
      refreshTask = task
      let result = await task.value
      refreshTask = nil
      return result
  }
  ```

### 5. NetworkMonitor — DispatchQueue.main.async in @MainActor class
- **File:** `MistyisletPass/Services/NetworkMonitor.swift:19-22`
- **Problem:** Uses legacy GCD `DispatchQueue.main.async` inside a `@MainActor` class. Suppresses compiler isolation checking.
- **Fix:** Replace with `Task { @MainActor [weak self] in ... }`

---

## P2 — Architecture / API Design

### 6. Three views bypass APIService for networking
- **Files:**
  - `MistyisletPass/Services/NotificationService.swift:31-43` (registerDeviceToken)
  - `MistyisletPass/Services/NFCService.swift:41-73` (bindCard)
  - `MistyisletPass/Views/Scanner/QRPassView.swift:182-206` (requestQRToken)
  - `MistyisletPass/Views/Profile/SiteSwitcherView.swift:89-106` (fetchSites)
- **Problem:** Each constructs raw URLRequest, reads Keychain token directly, uses URLSession.shared. No auto token-refresh on 401, no centralized error handling, no shared decoder.
- **Fix:** Add corresponding methods to `APIService`:
  ```swift
  func registerDeviceToken(_ token: String) async throws
  func bindNFCCard(cardUID: String, type: String, label: String) async throws -> Credential
  func fetchQRToken() async throws -> QRTokenResponse
  func fetchSites() async throws -> [Site]
  ```

### 7. Child views pass ViewModel as `let` instead of @Environment
- **Files:**
  - `SiteSwitcherView` → `let viewModel: ProfileViewModel`
  - `NFCBindingView` → `let viewModel: ProfileViewModel`
  - `CreateVisitorView` → `let viewModel: VisitorsViewModel`
  - `VisitorRowView` → `let viewModel: VisitorsViewModel`
  - `VisitorQRView` → `let viewModel: VisitorsViewModel`
- **Problem:** Passing `@Observable` class as `let` works for mutation but is not idiomatic SwiftUI. Should use `.environment()` injection for consistent observation tracking and decoupling.
- **Fix:** In parent views add `.environment(viewModel)`, in child views use `@Environment(VisitorsViewModel.self)`.

### 8. SiteSwitcherView — Inline networking in View, unused ViewModel param
- **File:** `MistyisletPass/Views/Profile/SiteSwitcherView.swift`
- **Problem:** `fetchSites()` does raw networking inside the View. `viewModel: ProfileViewModel` is accepted but never used. Uses inconsistent `JSONDecoder(.convertFromSnakeCase)` vs rest of app.
- **Fix:** Move to `ProfileViewModel.fetchSites()` or dedicated `SiteViewModel`. Use `APIService`.

### 9. Duplicate QR generation code
- **Files:**
  - `MistyisletPass/Views/Scanner/QRPassView.swift:146-159` (generateQRImage)
  - `MistyisletPass/ViewModels/VisitorsViewModel.swift:67-85` (generateQRCode)
- **Problem:** Nearly identical CIFilter QR generation pipelines.
- **Fix:** Extract to `Utilities/QRCodeGenerator.swift`.

---

## P3 — Performance / Code Quality

### 10. HapticService — Feedback generators created per-call
- **File:** `MistyisletPass/Services/HapticService.swift`
- **Problem:** Each call allocates a new `UIImpactFeedbackGenerator`/`UINotificationFeedbackGenerator`. `prepare()` called immediately before `impactOccurred()` provides no latency benefit.
- **Fix:** Store generators as instance properties, call `prepare()` in init:
  ```swift
  private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
  private let impactLight = UIImpactFeedbackGenerator(style: .light)
  private let notification = UINotificationFeedbackGenerator()
  ```

### 11. GlassEffectContainer missing for grouped glass elements
- **Files:**
  - `LoginView.swift:42,48` — two adjacent text fields with `.glassEffect`
  - `DoorCardView.swift:47,89` — card + hold button nested `.glassEffect`
  - `UnlockOverlayView.swift:47` — overlay glass without container
- **Problem:** Per Apple's iOS 26 Liquid Glass docs, multiple adjacent `.glassEffect` views should be wrapped in `GlassEffectContainer` for correct blur compositing and performance. Without it, each glass renders independently with visible seams.
- **Fix:** Wrap grouped elements:
  ```swift
  GlassEffectContainer {
      VStack { /* glass elements */ }
  }
  ```

### 12. SettingsServiceTests — Shared UserDefaults not reset between tests
- **File:** `MistyisletPassTests/SettingsServiceTests.swift`
- **Problem:** Tests use `SettingsService.shared` backed by `UserDefaults.standard` without reset. Results are order-dependent and affected by prior simulator state.
- **Fix:** Add `setUp`:
  ```swift
  override func setUp() {
      let domain = Bundle.main.bundleIdentifier!
      UserDefaults.standard.removePersistentDomain(forName: domain)
  }
  ```
  Or inject a test-specific `UserDefaults(suiteName:)`.

### 13. DeepLinkRouterTests — No tearDown cleanup
- **File:** `MistyisletPassTests/DeepLinkRouterTests.swift`
- **Problem:** `setUp` calls `clearPending()` but no `tearDown`. A failing test can leave dirty state.
- **Fix:** Add `override func tearDown() { router.clearPending() }`

### 14. BLEManager — `authResultContinuation` timeout race
- **File:** `MistyisletPass/Services/BLEManager.swift:66-73`
- **Problem:** Timeout fires on `bleQueue`, delegate also accesses continuation on `bleQueue`. Not atomic — two paths can race on the continuation.
- **Fix:** Use `NSLock` or `os_unfair_lock` to serialize continuation access:
  ```swift
  private let continuationLock = NSLock()
  private func takeContinuation() -> CheckedContinuation<UInt8, Error>? {
      continuationLock.withLock {
          let c = authResultContinuation
          authResultContinuation = nil
          return c
      }
  }
  ```

### 15. BLEManager — `discoveredControllers` never cleared
- **File:** `MistyisletPass/Services/BLEManager.swift:12-13`
- **Problem:** Stale peripherals accumulate. If a controller goes offline and returns with a new peripheral, the old one persists.
- **Fix:** Clear on `stopScanning()` or implement TTL-based eviction.

### 16. BLEManager — `willRestoreState` does not restore discoveredControllers
- **File:** `MistyisletPass/Services/BLEManager.swift:147-155`
- **Problem:** After background state restoration, `discoveredControllers` is empty. No scanning restart or peripheral re-mapping.
- **Fix:** Re-add restored peripherals to `discoveredControllers` and restart scanning.

### 17. Preview quality — ProfileView and others fire real API calls
- **Files:** `ProfileView`, `HistoryView`, `VisitorsView`, `DoorsView`
- **Problem:** `.task { await viewModel.fetch...() }` hits real API in previews, showing loading spinner or error forever.
- **Fix:** Use `#Preview` with injected mock data, or add a `isPreview` guard.

### 18. Missing test coverage for core flows
- **Problem:** No tests for DoorsViewModel unlock flow, AuthViewModel login, BLEManager, APIService networking, GeofenceService.
- **Fix:** Add unit tests with mocked APIService (protocol extraction) and verify state transitions.

---

## Summary

| Priority | Count | Description |
|----------|-------|-------------|
| **P0** | 2 | Functional bugs: biometric toggle doesn't work, geofence setting not persisted |
| **P1** | 3 | Swift 6 concurrency: BLEManager, APIService, NetworkMonitor |
| **P2** | 4 | Architecture: centralize networking, Environment injection, dedup code |
| **P3** | 9 | Performance & quality: haptics, glass containers, tests, previews |
| **Total** | **18** | |

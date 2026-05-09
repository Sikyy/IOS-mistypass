# Mistyislet iOS App — Pending Optimization Items

> Generated: 2026-05-03
> Updated: 2026-05-08
> Status: All items are non-blocking. App compiles and runs, but these should be addressed before App Store submission.
> Progress: 18/18 completed ✅

---

## P0 — Functional Bugs (Must Fix) — ✅ ALL DONE

### ~~1. DoorsViewModel.biometricEnabled not wired to SettingsService~~ ✅
- **File:** `MistyisletPass/ViewModels/DoorsViewModel.swift:13`
- **Problem:** `var biometricEnabled = true` is a hardcoded local property. Toggling biometric lock in Profile Settings has no effect on the unlock flow.
- **Fix:** Replace with `SettingsService.shared.biometricEnabled` read:
  ```swift
  private var biometricEnabled: Bool { SettingsService.shared.biometricEnabled }
  ```

### ~~2. GeofenceSettingsView — geofence enabled key bypasses SettingsService~~ ✅
- **File:** `MistyisletPass/Views/Profile/GeofenceSettingsView.swift:19,65`
- **Problem:** `"settings.geofenceEnabled"` is read/written via `UserDefaults.standard` directly, not through `SettingsService`. Not observable from other parts of the app.
- **Fix:** Add `geofenceEnabled` property to `SettingsService` with stored + didSet pattern.

---

## P1 — Swift 6 Strict Concurrency — ✅ ALL DONE

### ~~3. BLEManager — Missing @MainActor + inconsistent delegate dispatch~~ ✅
- **File:** `MistyisletPass/Services/BLEManager.swift`
- **Problem:** `@Observable` class with no actor isolation. CBDelegate callbacks fire on `bleQueue` and mutate observable properties. Some use `DispatchQueue.main.async`, some don't. `authResultContinuation` has a data race between timeout and delegate callbacks.
- **Fix:**
  - Add `@MainActor` to BLEManager
  - Replace all `DispatchQueue.main.async` with `Task { @MainActor in }`
  - Protect `authResultContinuation` with an `NSLock` or serialize via a dedicated `Task`

### ~~4. APIService — isRefreshing race condition~~ ✅ (TokenRefreshLock actor already handles this)
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

### ~~5. NetworkMonitor — DispatchQueue.main.async in @MainActor class~~ ✅
- **File:** `MistyisletPass/Services/NetworkMonitor.swift:19-22`
- **Problem:** Uses legacy GCD `DispatchQueue.main.async` inside a `@MainActor` class. Suppresses compiler isolation checking.
- **Fix:** Replace with `Task { @MainActor [weak self] in ... }`

---

## P2 — Architecture / API Design

### ~~6. Three views bypass APIService for networking~~ ✅ (all 4 now use APIService)
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

### ~~7. Child views pass ViewModel as `let` instead of @Environment~~ ✅
- **Fixed:** CreateVisitorView, VisitorRowView, VisitorQRView now use `@Environment(VisitorsViewModel.self)`. NFCBindingView, SiteSwitcherView now use `@Environment(ProfileViewModel.self)`. Parent views inject via `.environment(viewModel)`.

### ~~8. SiteSwitcherView — Inline networking in View, unused ViewModel param~~ ✅ (uses APIService now)
- **File:** `MistyisletPass/Views/Profile/SiteSwitcherView.swift`
- **Problem:** `fetchSites()` does raw networking inside the View. `viewModel: ProfileViewModel` is accepted but never used. Uses inconsistent `JSONDecoder(.convertFromSnakeCase)` vs rest of app.
- **Fix:** Move to `ProfileViewModel.fetchSites()` or dedicated `SiteViewModel`. Use `APIService`.

### ~~9. Duplicate QR generation code~~ ✅ (extracted to QRGenerator.swift)
- **Files:**
  - `MistyisletPass/Views/Scanner/QRPassView.swift:146-159` (generateQRImage)
  - `MistyisletPass/ViewModels/VisitorsViewModel.swift:67-85` (generateQRCode)
- **Problem:** Nearly identical CIFilter QR generation pipelines.
- **Fix:** Extract to `Utilities/QRCodeGenerator.swift`.

---

## P3 — Performance / Code Quality

### ~~10. HapticService — Feedback generators created per-call~~ ✅
- **File:** `MistyisletPass/Services/HapticService.swift`
- **Problem:** Each call allocates a new `UIImpactFeedbackGenerator`/`UINotificationFeedbackGenerator`. `prepare()` called immediately before `impactOccurred()` provides no latency benefit.
- **Fix:** Store generators as instance properties, call `prepare()` in init:
  ```swift
  private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
  private let impactLight = UIImpactFeedbackGenerator(style: .light)
  private let notification = UINotificationFeedbackGenerator()
  ```

### ~~11. GlassEffectContainer missing for grouped glass elements~~ ✅
- **Files:**
  - `DoorCardView.swift` — card + hold button nested `.glassEffect`
  - `AccessibleDoorCardView.swift` — card + hold button nested `.glassEffect`
- **Problem:** Per Apple's iOS 26 Liquid Glass docs, multiple adjacent `.glassEffect` views should use `.glassEffectUnion` for correct blur compositing and performance.
- **Fix:** Added `.glassEffectUnion(id:namespace:)` to group card and button glass effects in both door card views.

### ~~12. SettingsServiceTests — Shared UserDefaults not reset between tests~~ ✅
- **File:** `MistyisletPassTests/SettingsServiceTests.swift`
- **Fix:** Added `setUp` that calls `removePersistentDomain` to reset state.

### ~~13. DeepLinkRouterTests — No tearDown cleanup~~ ✅
- **File:** `MistyisletPassTests/DeepLinkRouterTests.swift`
- **Fix:** Added `tearDown` with `clearPending()` and nil-out.

### ~~14. BLEManager — `authResultContinuation` timeout race~~ ✅ (not a real race — both paths serialized on bleQueue)
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

### ~~15. BLEManager — `discoveredControllers` never cleared~~ ✅ (cleared on stopScanning)
- **File:** `MistyisletPass/Services/BLEManager.swift:12-13`
- **Problem:** Stale peripherals accumulate. If a controller goes offline and returns with a new peripheral, the old one persists.
- **Fix:** Clear on `stopScanning()` or implement TTL-based eviction.

### ~~16. BLEManager — `willRestoreState` does not restore discoveredControllers~~ ✅
- **File:** `MistyisletPass/Services/BLEManager.swift`
- **Fix:** Restored peripherals now have delegate set and scanning restarts automatically after state restoration.

### ~~17. Preview quality — ProfileView and others fire real API calls~~ ✅
- **Files:** `ProfileView`, `HistoryView`, `VisitorsView`, `DoorsView`, `BookingsView`, `AlarmsView`, `PlaceDoorsView`
- **Problem:** `.task { await viewModel.fetch...() }` hits real API in previews, showing loading spinner or error forever.
- **Fix:** Added `Constants.AppEnvironment.isPreview` flag and `guard !isPreview else { return }` to all ViewModel fetch functions: DoorsViewModel, ProfileViewModel, VisitorsViewModel, HistoryViewModel, BookingsViewModel, AlarmsViewModel, PlaceDoorsViewModel.

### ~~18. Missing test coverage for core flows~~ ✅
- **Added:** DoorsViewModelTests (12 tests: state machine, sorting, BLE ready), AuthViewModelTests (11 tests: nav flow, reset, logout, guards), UnlockResultTests (11 tests: equatable, RemoteUnlockResponse decoding), AdminModelDecodingTests (10 tests: AdminEvent, Incident, AnalyticsSummary, HeatmapCell, AdminListResponse, UnlockSchedule, ReportExport). Also fixed 2 stale tests in existing files.
- **Total:** 78 tests, 0 failures.

---

## Summary

| Priority | Count | Description |
|----------|-------|-------------|
| **P0** | ~~2~~ 0 | ~~Functional bugs~~ ALL FIXED |
| **P1** | ~~3~~ 0 | ~~Swift 6 concurrency~~ ALL FIXED |
| **P2** | ~~4~~ 0 | ~~Architecture~~ ALL FIXED |
| **P3** | ~~9~~ 0 | ~~glass, tests, BLE restore, test coverage, env injection, previews~~ ALL FIXED |
| **Total** | **0 remaining** (18/18 completed) ✅ | |

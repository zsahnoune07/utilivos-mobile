# utilivos-mobile PLAN.md

This plan is written so each phase can be delivered end-to-end with Codex. Milestones are concrete, testable, and sized for iterative shipping.

Scope: utilivos-mobile is the Flutter client for the Utilivos marketplace. **Release targets are Android and iOS only** (no web or desktop). The app has no login, no account creation, and no user profile flows. Pro access is a global store entitlement (one-time or subscription) that unlocks the full Pro tool catalog.

---

## Current repo reality

Observed structure includes:
- `lib/app.dart`, `lib/main.dart`
- `lib/core/theme/app_theme.dart`
- `lib/features/home/presentation/home_page.dart`
- `android/` and `ios/` host projects (mobile-only; no web or desktop folders)

Goal: deliver a feature-based Flutter app with Home-first installed tools, online catalog browsing for new tools, Pro purchase gating, secure bundle downloads, offline resilience, and release readiness.

---

## Principles

- Feature-first module boundaries.
- Predictable state management and routing.
- API-first DTO discipline with consistent error handling.
- Offline-friendly behavior for already verified Pro access.
- No user identity dependency in MVP.

---

## Tech decisions to lock early

Pick and standardize:
- State management: Riverpod
- Routing: `go_router`
- HTTP: `dio`
- Serialization: `json_serializable` (+ `freezed` optional)
- Local cache: drift or hive
- Secure storage: `flutter_secure_storage`
- Billing: `in_app_purchase`

Acceptance
- Decisions documented in `utilivos-mobile/README.md`.
- A minimal app run works on Android and iOS simulators.

---

## Phase 0: Project hygiene and foundations

### Milestone 0.1: Structure, lint, and CI
Tasks
- Keep/complete `core`, `features`, and `shared` structure.
- Enforce analyze/format/test in CI.
- Keep flavors (`dev`, `staging`, `prod`) with environment config.
- Add structured app logging with sensitive-field redaction.

Acceptance
- `flutter analyze` passes.
- `flutter test` runs in CI.
- Dev flavor launches locally.

Suggested Codex prompt
"Implement Phase 0.1 for utilivos-mobile: enforce core/features/shared structure, tighten analysis rules, add CI for format/analyze/test, and keep dev/staging/prod environment configuration working."

---

## Phase 1: Networking and API client

### Milestone 1.1: API client skeleton
Tasks
- Build `dio` client with:
  - base URL from environment
  - request id header
  - timeout/retry policy
  - normalized error mapping
- Add typed DTO conventions and pagination models.

Acceptance
- A debug call to `/v1/health` succeeds and displays status.

### Milestone 1.2: Anonymous device identity plumbing
Tasks
- Generate/store anonymous device id in secure storage.
- Attach device id on install and entitlement verification calls.
- Keep this id independent of any user account concept.

Acceptance
- Device id persists across app restarts and is available to API client.

Suggested Codex prompt
"Implement Phase 1 for utilivos-mobile: add a typed dio API client with interceptors/error mapping and an anonymous device-id store used in API request headers or payloads."

---

## Phase 2: App shell, navigation, and design system

### Milestone 2.1: Routing and shell
Tasks
- Implement `go_router` shell with tabs:
  - Home (installed tools)
  - Browse (online tool repository)
  - Settings
- Add splash/startup bootstrap route for config and entitlement preload.

Acceptance
- First launch after splash lands on Home, not Browse.
- Deep links work.
- Android back behavior is correct.

### Milestone 2.2: Shared UI components
Tasks
- Build reusable widgets:
  - buttons
  - cards
  - list tiles
  - loading/error/empty states
- Keep consistent visual states across all tabs.

Acceptance
- Shared states are reused, not duplicated per screen.

Suggested Codex prompt
"Implement Phase 2 for utilivos-mobile: add go_router shell (Home/Browse/Settings) with Home-first startup behavior, plus shared UI components for loading, empty, and error states."

---

## Phase 3: Catalog browsing and tool details

### Milestone 3.1: Discover catalog
Tasks
- Build category chips + searchable tool list.
- Implement cursor pagination.
- Wire endpoints:
  - `GET /v1/categories`
  - `GET /v1/plugins`

Acceptance
- Search and pagination are stable and debounced.

### Milestone 3.2: Tool detail page
Tasks
- Show tool metadata, version summary, changelog snippet, and pricing tier.
- Surface lock state for Pro tools when entitlement is inactive.
- Wire endpoint:
  - `GET /v1/plugins/:slug`

Acceptance
- Tool detail opens from list and reflects Pro lock state correctly.

Suggested Codex prompt
"Implement Phase 3 for utilivos-mobile: build browse catalog + tool detail screens with category filtering, search, pagination, and Pro lock state rendering for Pro tools."

---

## Phase 4: Purchase and entitlement

### Milestone 4.1: Store billing integration (Android / iOS)
Tasks
- Integrate `in_app_purchase` for Google Play and App Store billing.
- Configure Pro product IDs:
  - one-time purchase SKU (MVP default)
  - optional subscription SKU placeholder (extension)
- Build `Go Pro` purchase flow.
- Build `Restore purchases` flow.

Acceptance
- Test purchase path works in sandbox (Play / App Store).
- Restore path can recover previously purchased Pro.

### Milestone 4.2: Local entitlement persistence and UI gating
Tasks
- Persist entitlement status and last verification metadata in secure storage.
- Gate Pro tools in catalog/detail/install UI until entitlement is active.
- Show clear locked/upgrade CTAs and post-purchase unlock state.

Acceptance
- Pro tools remain locked before purchase.
- Successful purchase updates UI without requiring app restart.

Suggested Codex prompt
"Implement Phase 4 for utilivos-mobile: integrate store billing (Google Play and App Store) with Go Pro and Restore flows, persist entitlement state in secure storage, and gate Pro tool UI until entitlement is active."

---

## Phase 5: Verification and abuse resistance

### Milestone 5.1: Server verification handshake
Tasks
- After purchase/restore, call `POST /v1/entitlements/verify`.
- Store returned short-lived entitlement assertion and expiry.
- Use assertion when requesting Pro-gated bundle downloads.

Acceptance
- Verified purchases return active Pro entitlement in app state.
- Invalid verification response keeps Pro content locked.

### Milestone 5.2: Offline-friendly grace behavior
Tasks
- If entitlement was verified recently, allow Pro access for a grace window while offline.
- Re-verify in background when connectivity returns.
- Expire grace safely when verification remains stale.

Acceptance
- Previously verified Pro remains usable offline during grace period.
- App degrades to locked Pro state once grace expires.

Suggested Codex prompt
"Implement Phase 5 for utilivos-mobile: add entitlement verification calls to utilivos-api, store short-lived entitlement assertions, and implement offline grace-period logic with background re-verification."

---

## Phase 6: Home installed tools and secure bundle download

### Milestone 6.1: Installed tools flow (offline-first)
Tasks
- Implement install action:
  - `POST /v1/plugins/:slug/install`
- Show installed tools in Home:
  - `GET /v1/installs`
- Persist installed-tool metadata locally so Home works offline.
- Add a clear Home CTA to open Browse and install new tools.
- When online, refresh install state from API and check available updates via:
  - `GET /v1/plugins/:slug/versions`

Acceptance
- Installing a tool updates Home immediately.
- Previously installed tools remain visible and usable offline.
- Online sync flags update availability for installed tools.

### Milestone 6.2: Bundle download and integrity
Tasks
- Request signed download URL:
  - `GET /v1/plugins/:slug/download`
- Download with progress and store in app documents dir.
- Save local metadata (path/hash/version).
- Validate bundle hash when provided.

Acceptance
- Pro-tier bundle download succeeds only with active entitlement.
- Integrity mismatch is detected and handled safely.

### Milestone 6.3: Local plugin runtime launch
Tasks
- Add a plugin runtime route:
  - `/runtime/:slug`
- Extract downloaded `.utilivos.zip` bundles locally.
- Parse `manifest.json` and resolve local `entry` file path.
- Launch plugin UI inside an in-app WebView from local files.
- Add run CTA from Home installed-tools cards.
- After install succeeds, prepare runtime bundle and auto-launch when ready.

Acceptance
- Installed tools can be launched directly from Home.
- First install can launch tool runtime without manual file handling.
- Runtime launch gracefully reports missing/invalid bundle metadata.

Suggested Codex prompt
"Implement Phase 6 for utilivos-mobile: make Home installed-tools offline-first, add browse/install CTA from Home, sync installs and update checks when online, and keep Pro-gated downloads entitlement-protected."

---

## Phase 7: Offline support and performance

### Milestone 7.1: Catalog and metadata caching
Tasks
- Cache categories, tool list pages, and tool details.
- Cache entitlement timestamp/assertion metadata for startup decisions.
- Keep installed-tools cache as a first-class startup data source for Home.
- Define TTL and stale-data fallback strategy.

Acceptance
- App shows last known catalog data offline.

### Milestone 7.2: Performance polish
Tasks
- Add image caching and skeleton loaders.
- Reduce unnecessary rebuilds.
- Validate smooth scrolling on mid-tier Android profile.

Acceptance
- Interaction and scroll performance meet target baseline.

Suggested Codex prompt
"Implement Phase 7 for utilivos-mobile: add offline cache for catalog/detail data, entitlement metadata, and installed tools, then optimize rendering and loading UX for smooth mid-tier Android performance."

---

## Phase 8: Testing strategy

### Milestone 8.1: Unit and widget tests
Tasks
- Unit tests:
  - entitlement state transitions
  - grace window decisions
  - API error mapping
- Widget tests:
  - Pro lock states
  - purchase CTA states
  - browse list rendering
  - home installed-tools offline rendering

Acceptance
- Tests are stable in CI.

### Milestone 8.2: Integration smoke test
Tasks
- End-to-end smoke test:
  - launch app
  - open Home installed tools
  - open Browse and inspect a tool detail
  - simulate entitlement verification success
  - request Pro bundle download

Acceptance
- Integration test runs on at least one CI target.

Suggested Codex prompt
"Implement Phase 8 for utilivos-mobile: add unit/widget tests for entitlement and Pro lock behavior, plus an integration smoke test covering discover, verification success, and Pro bundle download request."

---

## Phase 9: Release readiness

### Milestone 9.1: Telemetry and diagnostics
Tasks
- Add crash reporting (Sentry or Crashlytics).
- Add analytics events for:
  - upgrade tap
  - purchase success/failure
  - restore success/failure
  - Pro bundle download attempts

Acceptance
- Events visible in dev/staging dashboards.

### Milestone 9.2: Build and deploy automation
Tasks
- Keep CI/Fastlane scripts for Android/iOS builds.
- Standardize app versioning and release notes.

Acceptance
- CI can produce signed staging artifacts.

---

## Definition of done per milestone

- App compiles on Android and iOS.
- No secrets committed.
- Tests cover new logic.
- UI has loading/empty/error states.
- README updated when setup or configuration changes.

---

## Future extension: Optional accounts later

Accounts may be introduced later for cross-device sync and identity-based reviews. MVP Pro entitlement and tool access must remain functional without accounts.

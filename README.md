# utilivos-mobile

Flutter client for the Utilivos marketplace. **Ships for Android and iOS only** (not web or desktop).

## Product Scope (Current)

`utilivos-mobile` now follows the marketplace MVP direction in `PLAN.md`:

- anonymous usage (no login/register/profile route in active app flow)
- purchase-based Pro access
- Home-first installed tools with online catalog browsing

Implemented product behavior:

- splash bootstrap initializes persistent anonymous device ID
- `go_router` shell with tabs:
  - Home
  - Browse
  - Settings
- Home installed-tools integration:
  - local Drift/SQLite persistence for installed tools
  - `GET /v1/installs` sync when online
  - update checks with `GET /v1/plugins/:slug/versions`
  - tap installed tool card to launch directly
- Browse catalog integration:
  - `GET /v1/categories`
  - `GET /v1/plugins` with debounced search + cursor pagination
  - tool detail route (`/discover/plugin/:slug`)
  - `GET /v1/plugins/:slug`
  - `GET /v1/plugins/:slug/versions`
  - secure offline cache for:
    - category list
    - plugin list pages (query + cursor keyed)
    - plugin detail and versions
  - cache strategy:
    - fresh TTL: 30 minutes
    - stale fallback window for network/server errors: 14 days
  - cached thumbnail loading for tool artwork via `cached_network_image`
- Install tracking integration:
  - `POST /v1/plugins/:slug/install` from plugin detail
  - immediate Home cache update after install
- Bundle download integration:
  - signed URL grant request via `GET /v1/plugins/:slug/download`
  - entitlement assertion header for Pro-tier bundles
  - local file persistence + SHA-256 integrity validation when checksum is provided
  - bundle extraction + manifest entry resolution
  - downloaded bundle metadata persistence (archive path/hash/version + manifest/entry paths)
- Plugin runtime integration:
  - dedicated runtime route: `/runtime/:slug`
  - in-app WebView (`webview_flutter`) for plugin UI
  - runtime loads plugin `manifest.json` entry file from extracted bundle
  - install flow prepares runtime bundle and auto-launches when ready
  - runtime launch is local/offline once bundle is prepared (no network call required to run)
- Pro purchase and entitlement integration:
  - store billing (Google Play / App Store) via `in_app_purchase`
  - upgrade flow (one-time SKU by default)
  - restore purchases flow
  - server verification via `POST /v1/entitlements/verify`
  - local secure entitlement + assertion metadata persistence
  - offline grace window for previously verified entitlement
  - background re-verification (periodic + app resume)
  - Pro lock/unlock gating in Browse, tool detail, and install CTA behavior
- Performance polish:
  - sliver-based lazy rendering for Discover and Home installed-tools lists
  - repaint boundaries for catalog and installed-tool cards
  - skeleton loading cards for catalog, installed tools, and tool detail
- shared loading/empty/error states and UI components across screens

## Technical Decisions and Status

- Routing: `go_router` (implemented)
- HTTP: `dio` (implemented)
- Secure storage: `flutter_secure_storage` for tokens/secrets (implemented)
- Local data: Drift/SQLite for catalog cache, installed tools list, and sync metadata (implemented)
- Anonymous device identity: secure-store + `X-Device-ID` header interceptor (implemented)
- Billing: `in_app_purchase` (implemented)
- Local entitlement persistence: secure-store backed controller (implemented)
- Local catalog cache: Drift-backed TTL/stale fallback (implemented)
- Image caching: `cached_network_image` with skeleton placeholders (implemented)
- State management: `ChangeNotifier` for feature controllers; `flutter_riverpod` for app-wide dependencies and install streams

## Development

Copy [`.env.example`](.env.example) to `.env.build` (gitignored), fill in values, then build or run with all `String.fromEnvironment` keys applied:

```bash
cp .env.example .env.build
# edit .env.build — optional MOBILE_CLIENT_*_FILE paths for secrets on disk
UTILIVOS_BUILD_ENV_FILE=.env.build tool/flutter_build_from_env.sh run
UTILIVOS_BUILD_ENV_FILE=.env.build tool/flutter_build_from_env.sh build apk --release
```

See comments in `.env.example` and [`tool/flutter_build_from_env.sh`](tool/flutter_build_from_env.sh). The app does **not** read `.env` at runtime; values must reach the compiler as `--dart-define` (or `--dart-define-from-file`).

**Wrong:** `flutter run --dart-define=UTILIVOS_BUILD_ENV_FILE=.env.dev` — that name is only a **shell** variable for `flutter_build_from_env.sh`, not a Dart `fromEnvironment` key, so the API URL (and other keys) are never applied.

**Right — native Flutter (no script):** from `utilivos-mobile/`, after copying `.env.example` to e.g. `.env.dev`:

```bash
flutter pub get
flutter run --dart-define-from-file=.env.dev
```

**Right — script** (also expands `MOBILE_CLIENT_*_FILE` / `PINNED_SIGNING_ROOT_PUBLIC_KEY_FILE` into defines; `--dart-define-from-file` does not):

```bash
UTILIVOS_BUILD_ENV_FILE=.env.dev tool/flutter_build_from_env.sh run
```

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Optional:

```bash
flutter run --dart-define=APP_NAME=Utilivos --dart-define=API_BASE_URL=http://localhost:8080
```

Run with a local `.ubb` tool deliverable pre-seeded on startup:

```bash
flutter run \
  --dart-define=LOCAL_TOOL_BUNDLE_PATH=/media/Shared/Projects/Utilivo_Market/free/btc-util/dist/btc-util-1.0.0.ubb
```

Optional local-bundle overrides (defaults are read from `manifest.json`):

```bash
--dart-define=LOCAL_TOOL_BUNDLE_SLUG=btc-util
--dart-define=LOCAL_TOOL_BUNDLE_VERSION=1.0.0
```

Billing-related defines (Android: one Play subscription, two base plans):

```bash
flutter run \
  --dart-define=PREMIUM_SUBSCRIPTION_PRODUCT_ID=utilivos_pro_subscription \
  --dart-define=PREMIUM_SUBSCRIPTION_MONTHLY_BASE_PLAN_ID=monthly \
  --dart-define=PREMIUM_SUBSCRIPTION_ANNUAL_BASE_PLAN_ID=annual \
  --dart-define=ANDROID_PACKAGE_NAME=com.utilivos.app \
  --dart-define=PINNED_SIGNING_ROOT_PUBLIC_KEY="$(cat signing-root-public.pem)"
```

Optional lifetime SKU: `PREMIUM_ONE_TIME_PRODUCT_ID=...` (omit or empty for subscriptions-only).

## Production / VPS

- **Env template:** copy [`.env.vps.example`](.env.vps.example) to a gitignored file (e.g. `.env.build`), set `API_BASE_URL` to your **HTTPS** API origin, billing SKUs, and optional `MOBILE_CLIENT_*` / `PINNED_SIGNING_ROOT_PUBLIC_KEY` to match [utilivos-api](../utilivos-api).
- **Sentry:** set `SENTRY_DSN` in that same file (see [`.env.example`](.env.example)). When non-empty, [lib/main.dart](lib/main.dart) initializes Sentry and [lib/core/di/app_dependencies.dart](lib/core/di/app_dependencies.dart) uses [SentryProAnalytics](lib/core/pro/pro_analytics.dart) for Pro funnel breadcrumbs.
- **Device QA:** follow [docs/DEVICE_SMOKE_CHECKLIST.md](docs/DEVICE_SMOKE_CHECKLIST.md).
- **Store billing:** follow [docs/STORE_SANDBOX_VALIDATION.md](docs/STORE_SANDBOX_VALIDATION.md).
- **Ship artifacts:** see [docs/RELEASE_BUILD.md](docs/RELEASE_BUILD.md).
- **Bundle signing pin:** `PINNED_SIGNING_ROOT_PUBLIC_KEY` must be the **root public** PEM (`BEGIN PUBLIC KEY`), not anything from `bundle-signing-*-private.pem`. Derive it with `openssl pkey -in bundle-signing-root-private.pem -pubout`, then set `PINNED_SIGNING_ROOT_PUBLIC_KEY_FILE` in `.env.build` to that `.pem` path (see [`.env.example`](.env.example)); the build script inlines it into `--dart-define`.

**Integration test harness:** with an Android emulator or iOS simulator available, run `flutter test integration_test/app_binding_test.dart` (this project is mobile-only; the command fails on unsupported hosts such as Linux desktop alone).

## Quality Checks

```bash
flutter analyze
flutter test
```

CI (`.github/workflows/mobile.yml`) enforces:

- format (`dart format --set-exit-if-changed`)
- analyze
- test

## Performance Profiling

Use profile mode on a physical Android or iOS device:

```bash
flutter run --profile --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Validation checklist:

- Open Home and Discover.
- Scroll long lists continuously for at least 30 seconds.
- Verify there are no obvious dropped-frame stalls during steady scroll.
- Trigger search/category changes in Discover and verify list updates stay responsive.

## Debug Screen

Route: `/discover/debug`

Capabilities:

- `/v1/health` smoke call
- active API base URL display
- anonymous device ID diagnostics/regeneration

# utilivo-mobile

Flutter client for the Utilivo marketplace.

## Product Scope (Current)

`utilivo-mobile` now follows the marketplace MVP direction in `PLAN.md`:
- anonymous usage (no login/register/profile route in active app flow)
- purchase-based premium access
- Home-first installed tools with online catalog browsing

Implemented product behavior:
- splash bootstrap initializes persistent anonymous device ID
- `go_router` shell with tabs:
  - Home
  - Browse
  - Settings
- Home installed-tools integration:
  - secure offline cache of installed tools
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
  - entitlement assertion header for premium bundles
  - local file persistence + SHA-256 integrity validation when checksum is provided
  - bundle extraction + manifest entry resolution
  - downloaded bundle metadata persistence (archive path/hash/version + manifest/entry paths)
- Plugin runtime integration:
  - dedicated runtime route: `/runtime/:slug`
  - local web container via `webview_flutter`
  - runtime loads plugin `manifest.json` entry file from extracted bundle
  - install flow prepares runtime bundle and auto-launches when ready
  - runtime launch is local/offline once bundle is prepared (no network call required to run)
- Premium purchase and entitlement integration:
  - Google Play billing gateway integration via `in_app_purchase`
  - upgrade flow (one-time SKU by default)
  - restore purchases flow
  - server verification via `POST /v1/entitlements/verify`
  - local secure entitlement + assertion metadata persistence
  - offline grace window for previously verified entitlement
  - background re-verification (periodic + app resume)
  - premium lock/unlock gating in Browse, tool detail, and install CTA behavior
- Performance polish:
  - sliver-based lazy rendering for Discover and Home installed-tools lists
  - repaint boundaries for catalog and installed-tool cards
  - skeleton loading cards for catalog, installed tools, and tool detail
- shared loading/empty/error states and UI components across screens

## Technical Decisions and Status

- Routing: `go_router` (implemented)
- HTTP: `dio` (implemented)
- Secure storage: `flutter_secure_storage` (implemented)
- Anonymous device identity: secure-store + `X-Device-ID` header interceptor (implemented)
- Billing: `in_app_purchase` (implemented)
- Local entitlement persistence: secure-store backed controller (implemented)
- Local catalog cache: secure-store backed TTL/stale fallback (implemented)
- Image caching: `cached_network_image` with skeleton placeholders (implemented)
- State management: currently `ChangeNotifier` + local widget state; Riverpod adoption remains planned

## Development

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Optional:

```bash
flutter run --dart-define=APP_NAME=Utilivo --dart-define=API_BASE_URL=http://localhost:8080
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

Billing-related defines:

```bash
flutter run \
  --dart-define=PREMIUM_ONE_TIME_PRODUCT_ID=utilivo_premium_one_time \
  --dart-define=PREMIUM_SUBSCRIPTION_PRODUCT_ID=utilivo_premium_subscription \
  --dart-define=ANDROID_PACKAGE_NAME=com.utilivo.utilivo_mobile
```

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

Use profile mode on an Android test device:

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

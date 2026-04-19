#!/usr/bin/env bash
# Load build-time variables from a dotenv-style file and run `flutter` with
# matching --dart-define flags. Optional *_FILE keys inject secret file contents
# (MOBILE_CLIENT_*_FILE, PINNED_SIGNING_ROOT_PUBLIC_KEY_FILE).
#
# UTILIVOS_BUILD_ENV_FILE is a **shell** variable for this script only. It is
# not read by the Flutter app. Do not pass it as `--dart-define=...`; use either
# this script or `flutter run --dart-define-from-file=.env.dev` (see README).
#
# Usage (from utilivos-mobile repo root):
#   UTILIVOS_BUILD_ENV_FILE=.env.build tool/flutter_build_from_env.sh build apk --release
#   tool/flutter_build_from_env.sh .env.staging build ios --release
#
# You may prefix with `flutter` if you prefer:
#   tool/flutter_build_from_env.sh .env.build flutter build apk --release
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ENV_FILE="${UTILIVOS_BUILD_ENV_FILE:-.env.build}"
if [[ "${1:-}" == -* ]]; then
  :
elif [[ -n "${1:-}" && -f "$ROOT/$1" ]]; then
  ENV_FILE="$ROOT/$1"
  shift
elif [[ -n "${1:-}" && -f "$1" ]]; then
  ENV_FILE="$1"
  shift
fi

if [[ "$ENV_FILE" != /* ]]; then
  ENV_FILE="$ROOT/$ENV_FILE"
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "error: env file not found: $ENV_FILE" >&2
  echo "Create it from .env.example or set UTILIVOS_BUILD_ENV_FILE." >&2
  exit 1
fi

while IFS= read -r __line || [[ -n $__line ]]; do
  [[ "$__line" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${__line//[[:space:]]/}" ]] && continue
  if [[ "$__line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    _k="${BASH_REMATCH[1]}"
    _v="${BASH_REMATCH[2]}"
    _v="${_v%$'\r'}"
    if [[ "$_v" =~ ^\".*\"$ ]]; then
      _v="${_v#\"}"
      _v="${_v%\"}"
    elif [[ "$_v" =~ ^\'.*\'$ ]]; then
      _v="${_v#\'}"
      _v="${_v%\'}"
    fi
    export "$_k=$_v"
  fi
done <"$ENV_FILE"

read_secret_file() {
  local file_path="${1:-}"
  if [[ -n "$file_path" && -f "$file_path" ]]; then
    tr -d '\r\n' <"$file_path"
  fi
}

if [[ -n "${MOBILE_CLIENT_SHARED_SECRET_FILE:-}" ]]; then
  _s="$(read_secret_file "$MOBILE_CLIENT_SHARED_SECRET_FILE")"
  if [[ -n "$_s" ]]; then
    export MOBILE_CLIENT_SHARED_SECRET="$_s"
  fi
fi
if [[ -n "${MOBILE_CLIENT_SIGNATURE_SECRET_FILE:-}" ]]; then
  _s="$(read_secret_file "$MOBILE_CLIENT_SIGNATURE_SECRET_FILE")"
  if [[ -n "$_s" ]]; then
    export MOBILE_CLIENT_SIGNATURE_SECRET="$_s"
  fi
fi

# PEM public key (SPKI, BEGIN PUBLIC KEY) collapsed to one line for --dart-define.
if [[ -n "${PINNED_SIGNING_ROOT_PUBLIC_KEY_FILE:-}" ]]; then
  _pem="$(read_secret_file "$PINNED_SIGNING_ROOT_PUBLIC_KEY_FILE")"
  if [[ -n "$_pem" ]]; then
    export PINNED_SIGNING_ROOT_PUBLIC_KEY="$_pem"
  fi
fi

_dart_define_keys=(
  APP_NAME
  API_BASE_URL
  ANDROID_PACKAGE_NAME
  PREMIUM_ONE_TIME_PRODUCT_ID
  PREMIUM_SUBSCRIPTION_PRODUCT_ID
  PREMIUM_SUBSCRIPTION_MONTHLY_BASE_PLAN_ID
  PREMIUM_SUBSCRIPTION_ANNUAL_BASE_PLAN_ID
  PINNED_SIGNING_ROOT_PUBLIC_KEY
  LOCAL_TOOL_BUNDLE_PATH
  LOCAL_TOOL_BUNDLE_SLUG
  LOCAL_TOOL_BUNDLE_VERSION
  TOOL_REPORT_SUBMIT_URL
  IOS_APP_STORE_ID
  MOBILE_CLIENT_SHARED_SECRET
  MOBILE_CLIENT_SIGNATURE_SECRET
  SENTRY_DSN
)

dart_defines=()
for _k in "${_dart_define_keys[@]}"; do
  if declare -p "$_k" &>/dev/null; then
    _v="${!_k}"
    if [[ -n "$_v" ]]; then
      dart_defines+=(--dart-define="$_k=$_v")
    fi
  fi
done

if [[ $# -eq 0 ]]; then
  echo "error: pass flutter arguments, e.g. build apk --release" >&2
  exit 1
fi

if [[ "${1:-}" == flutter ]]; then
  shift
fi

exec flutter "${dart_defines[@]}" "$@"

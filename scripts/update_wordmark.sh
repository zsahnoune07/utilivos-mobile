#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ASSET_PATH="${PROJECT_ROOT}/assets/wordmark.svg"
SOURCE_PATH="${1:-}"

find_text() {
  local pattern="$1"
  local target="$2"

  if command -v rg >/dev/null 2>&1; then
    rg -q "${pattern}" "${target}"
  else
    grep -R -E -q "${pattern}" "${target}"
  fi
}

if [[ -n "${SOURCE_PATH}" ]]; then
  if [[ ! -f "${SOURCE_PATH}" ]]; then
    echo "Error: source SVG not found: ${SOURCE_PATH}" >&2
    echo "Usage: scripts/update_wordmark.sh [path/to/wordmark.svg]" >&2
    exit 1
  fi

  cp "${SOURCE_PATH}" "${ASSET_PATH}"
  echo "Updated ${ASSET_PATH}"
else
  if [[ ! -f "${ASSET_PATH}" ]]; then
    echo "Error: asset not found: ${ASSET_PATH}" >&2
    exit 1
  fi

  echo "Using existing asset: ${ASSET_PATH}"
fi

if ! find_text "assets/wordmark\\.svg" "${PROJECT_ROOT}/pubspec.yaml"; then
  echo "Error: pubspec.yaml is not registering assets/wordmark.svg" >&2
  exit 1
fi

if ! find_text "assets/wordmark\\.svg" "${PROJECT_ROOT}/lib"; then
  echo "Error: no widget is currently referencing assets/wordmark.svg" >&2
  exit 1
fi

echo "Wordmark wiring is valid."
echo "Hot restart or rebuild the app to see the updated SVG."

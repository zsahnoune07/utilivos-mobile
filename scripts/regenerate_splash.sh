#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_IMAGE="${1:-${PROJECT_ROOT}/assets/splash.png}"

if [[ ! -f "${SOURCE_IMAGE}" ]]; then
  echo "Error: splash source not found: ${SOURCE_IMAGE}" >&2
  echo "Usage: scripts/regenerate_splash.sh [path/to/splash.png]" >&2
  exit 1
fi

if ! command -v convert >/dev/null 2>&1; then
  echo "Error: ImageMagick 'convert' is required but not installed." >&2
  exit 1
fi

generate_padded() {
  local src="$1"
  local canvas="$2"
  local inner="$3"
  local dst="$4"

  mkdir -p "$(dirname "${dst}")"
  convert "${src}" \
    -resize "${inner}x${inner}" \
    -background none \
    -gravity center \
    -extent "${canvas}x${canvas}" \
    "${dst}"
}

echo "Generating splash assets from: ${SOURCE_IMAGE}"

# Android splash assets (60% visible content within each square canvas).
generate_padded "${SOURCE_IMAGE}" 240 144 "${PROJECT_ROOT}/android/app/src/main/res/drawable/splash.png"
generate_padded "${SOURCE_IMAGE}" 240 144 "${PROJECT_ROOT}/android/app/src/main/res/drawable-mdpi/splash.png"
generate_padded "${SOURCE_IMAGE}" 360 216 "${PROJECT_ROOT}/android/app/src/main/res/drawable-hdpi/splash.png"
generate_padded "${SOURCE_IMAGE}" 480 288 "${PROJECT_ROOT}/android/app/src/main/res/drawable-xhdpi/splash.png"
generate_padded "${SOURCE_IMAGE}" 720 432 "${PROJECT_ROOT}/android/app/src/main/res/drawable-xxhdpi/splash.png"
generate_padded "${SOURCE_IMAGE}" 960 576 "${PROJECT_ROOT}/android/app/src/main/res/drawable-xxxhdpi/splash.png"

# iOS launch image variants.
generate_padded "${SOURCE_IMAGE}" 168 126 "${PROJECT_ROOT}/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png"
generate_padded "${SOURCE_IMAGE}" 336 252 "${PROJECT_ROOT}/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png"
generate_padded "${SOURCE_IMAGE}" 504 378 "${PROJECT_ROOT}/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png"

echo "Splash assets regenerated successfully."

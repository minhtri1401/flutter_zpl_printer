#!/usr/bin/env bash
# Mirrors the canonical darwin/Classes/** sources into ios/Classes/ and
# macos/Classes/. Run after regenerating Pigeon output or editing any of the
# Usb Swift files.
#
# CocoaPods does not follow symlinks into a pod's source_files glob, so we
# duplicate files instead. darwin/ remains the single source of truth.

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for platform in ios macos; do
  DEST="${REPO_ROOT}/${platform}/Classes"
  mkdir -p "${DEST}/Usb"
  cp "${REPO_ROOT}/darwin/Classes/UsbMessages.g.swift" "${DEST}/UsbMessages.g.swift"
  cp "${REPO_ROOT}/darwin/Classes/Usb/"*.swift "${DEST}/Usb/"
  echo "✓ Synced darwin → ${platform}/Classes/"
done

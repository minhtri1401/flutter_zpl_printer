#!/usr/bin/env bash
# Fetches libusb pre-built binaries into third_party/libusb/<VERSION>/.
# Run from the repo root. Requires: curl, 7z (for Windows archive).
#
# Supported sources:
#   - Windows: official pre-built from libusb releases (.7z, x64+arm64 DLLs)
#   - macOS:   copied from Homebrew's libusb if installed locally
#   - Android: must be built from source with NDK (see DEVELOPING.md)
#
# After placing binaries, regenerate CHECKSUMS:
#   cd third_party/libusb/<VERSION> && find . -type f \
#     \( -name "*.so" -o -name "*.dylib" -o -name "*.dll" \) \
#     -exec shasum -a 256 {} \; > CHECKSUMS

set -euo pipefail

VERSION="${LIBUSB_VERSION:-1.0.29}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${REPO_ROOT}/third_party/libusb/${VERSION}"

mkdir -p "${DEST}"/{android/{armeabi-v7a,arm64-v8a,x86,x86_64},macos,windows/{x64,arm64}}

# ── macOS from Homebrew ────────────────────────────────────────────────────
BREW_LIB="/opt/homebrew/Cellar/libusb/${VERSION}/lib/libusb-1.0.dylib"
if [[ -f "${BREW_LIB}" ]]; then
  cp "${BREW_LIB}" "${DEST}/macos/libusb-1.0.dylib"
  echo "✓ macOS libusb-1.0.dylib copied from Homebrew"
else
  echo "⚠ macOS libusb not found at ${BREW_LIB}"
  echo "  → Install with: brew install libusb"
fi

# ── Windows from upstream ──────────────────────────────────────────────────
if command -v 7z >/dev/null 2>&1; then
  echo "Fetching Windows binaries from libusb upstream..."
  TMP="$(mktemp -d)"
  curl -fSL "https://github.com/libusb/libusb/releases/download/v${VERSION}/libusb-${VERSION}-binaries.7z" \
    -o "${TMP}/libusb.7z" || echo "⚠ Windows fetch failed; place manually"
  if [[ -s "${TMP}/libusb.7z" ]]; then
    7z x -o"${TMP}/ext" "${TMP}/libusb.7z" >/dev/null
    # Upstream layout: VS2022/MS64/dll/libusb-1.0.dll and VS2022/MS32/dll/libusb-1.0.dll
    find "${TMP}/ext" -name "libusb-1.0.dll" | while read -r DLL; do
      case "${DLL}" in
        *MS64*) cp "${DLL}" "${DEST}/windows/x64/libusb-1.0.dll"; echo "✓ Windows x64 DLL placed" ;;
        *ARM64*) cp "${DLL}" "${DEST}/windows/arm64/libusb-1.0.dll"; echo "✓ Windows arm64 DLL placed" ;;
      esac
    done
  fi
  rm -rf "${TMP}"
else
  echo "⚠ 7z not found; Windows DLLs must be placed manually."
  echo "  → Install with: brew install sevenzip"
fi

# ── Android requires NDK build — document only ─────────────────────────────
echo ""
echo "Android libusb (.so) must be built from source with NDK."
echo "See DEVELOPING.md for instructions. Expected layout:"
for ABI in armeabi-v7a arm64-v8a x86 x86_64; do
  echo "  ${DEST}/android/${ABI}/libusb-1.0.so"
done

# ── Regenerate CHECKSUMS ───────────────────────────────────────────────────
(
  cd "${DEST}"
  find . -type f \( -name "*.so" -o -name "*.dylib" -o -name "*.dll" \) \
    | sort | while read -r FILE; do
    shasum -a 256 "${FILE}"
  done
) > "${DEST}/CHECKSUMS"
echo ""
echo "CHECKSUMS updated:"
cat "${DEST}/CHECKSUMS"

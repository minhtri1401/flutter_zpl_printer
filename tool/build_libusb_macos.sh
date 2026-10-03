#!/usr/bin/env bash
# Builds a universal (arm64 + x86_64) libusb for macOS from the official
# release tarball and packages it as
# darwin/flutter_zpl_printer/Frameworks/libusb.xcframework.
#
# Both CocoaPods (podspec vendored_frameworks) and Swift Package Manager
# (Package.swift binaryTarget) embed that xcframework into the app's
# Contents/Frameworks/, where LibusbLoader looks for it.
#
# The xcframework wraps a plain .dylib, not a .framework bundle: macOS
# frameworks rely on symlinks, which `dart pub publish` turns into copies.
#
# Run from anywhere. Requires Xcode command line tools.

set -euo pipefail

VERSION="${LIBUSB_VERSION:-1.0.29}"
# sha256 of libusb-1.0.29.tar.bz2, as published on the GitHub release.
SHA256="${LIBUSB_SHA256:-5977fc950f8d1395ccea9bd48c06b3f808fd3c2c961b44b0c2e6e29fc3a70a85}"
MIN_MACOS="10.15"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${REPO_ROOT}/darwin/flutter_zpl_printer/Frameworks/libusb.xcframework"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

cd "${WORK}"
curl -fsSLO "https://github.com/libusb/libusb/releases/download/v${VERSION}/libusb-${VERSION}.tar.bz2"
echo "${SHA256}  libusb-${VERSION}.tar.bz2" | shasum -a 256 -c -
tar xjf "libusb-${VERSION}.tar.bz2"

ARCH_FLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${MIN_MACOS}"
(
  cd "libusb-${VERSION}"
  ./configure --prefix="${WORK}/out" --disable-static --disable-dependency-tracking \
    CFLAGS="${ARCH_FLAGS} -O2" LDFLAGS="${ARCH_FLAGS}" >/dev/null
  make -j"$(sysctl -n hw.ncpu)" >/dev/null
  make install >/dev/null
)

mkdir -p lib
cp "out/lib/libusb-1.0.0.dylib" lib/libusb-1.0.dylib
install_name_tool -id "@rpath/libusb-1.0.dylib" lib/libusb-1.0.dylib
codesign --force --sign - lib/libusb-1.0.dylib

rm -rf "${DEST}"
xcodebuild -create-xcframework \
  -library lib/libusb-1.0.dylib \
  -headers out/include/libusb-1.0 \
  -output "${DEST}" >/dev/null

lipo -info "${DEST}"/*/libusb-1.0.dylib
echo "✓ ${DEST#"${REPO_ROOT}"/}"

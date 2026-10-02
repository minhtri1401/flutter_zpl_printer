# libusb 1.0.29 — bundled binary

This folder holds pre-built libusb shared libraries bundled with `flutter_zpl_printer`.
They are checked into the repository for reproducibility and offline builds.

## Layout

```
third_party/libusb/1.0.29/
├── libusb.h                         — header used by ffigen
├── LICENSE                          — LGPL-2.1-or-later (upstream COPYING)
├── CHECKSUMS                        — sha256 per binary; verified in CI
├── android/
│   ├── armeabi-v7a/libusb-1.0.so    — manual build from source + NDK
│   ├── arm64-v8a/libusb-1.0.so
│   ├── x86/libusb-1.0.so
│   └── x86_64/libusb-1.0.so
├── macos/
│   └── libusb-1.0.dylib             — universal (x86_64 + arm64)
└── windows/
    ├── x64/libusb-1.0.dll
    └── arm64/libusb-1.0.dll
```

## Regenerating binaries

Run `tool/fetch_libusb.sh` from the repo root. It:

- Copies `libusb-1.0.dylib` from Homebrew if `brew install libusb` was run locally.
- Fetches the official Windows pre-built archive from libusb upstream releases and extracts x64 + arm64 DLLs.
- Documents the Android-from-source step (NDK required; see `DEVELOPING.md`).
- Regenerates `CHECKSUMS`.

## License

libusb is distributed under **LGPL-2.1-or-later**. This SDK links libusb
*dynamically* (shared library). The consumer app bundles the .so/.dylib/.dll
via this plugin's packaging rules. LGPL requires that the consumer provides
relink capability — which is satisfied by shipping the shared libraries
unmodified and allowing end-users to replace them with their own build.

See `LICENSE` for the full text.

// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "flutter_zpl_printer",
  platforms: [
    .iOS("13.0"),
    .macOS("10.15"),
  ],
  products: [
    .library(name: "flutter-zpl-printer", targets: ["flutter_zpl_printer"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    .target(
      name: "flutter_zpl_printer",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework"),
        // libusb is loaded at runtime with dart:ffi; this only embeds it in
        // the app's Contents/Frameworks/. Built by tool/build_libusb_macos.sh.
        .target(name: "libusb", condition: .when(platforms: [.macOS])),
      ],
      resources: [
        .process("PrivacyInfo.xcprivacy")
      ]
    ),
    .binaryTarget(name: "libusb", path: "Frameworks/libusb.xcframework"),
  ]
)

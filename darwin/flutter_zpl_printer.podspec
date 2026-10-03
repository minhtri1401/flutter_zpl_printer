#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_zpl_printer.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_zpl_printer'
  s.version          = '0.2.0'
  s.summary          = 'Flutter plugin for Zebra ZPL label printers (BLE, TCP, USB).'
  s.description      = <<-DESC
Discover, connect to, and print on Zebra ZPL label printers over Bluetooth LE, Wi-Fi/TCP, and USB.
                       DESC
  s.homepage         = 'https://github.com/minhtri1401/flutter_zpl_printer'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'minhtri1401' => 'https://github.com/minhtri1401' }
  s.source           = { :path => '.' }

  # Shared with Swift Package Manager (flutter_zpl_printer/Package.swift).
  s.source_files = 'flutter_zpl_printer/Sources/flutter_zpl_printer/**/*.swift'
  s.resource_bundles = {
    'flutter_zpl_printer_privacy' => ['flutter_zpl_printer/Sources/flutter_zpl_printer/PrivacyInfo.xcprivacy']
  }

  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'

  # libusb for dart:ffi, embedded in the app's Contents/Frameworks/.
  # Built by tool/build_libusb_macos.sh. CocoaPods can't vendor an xcframework
  # of dylibs, so it takes the dylib from the slice Package.swift uses.
  s.osx.vendored_libraries = 'flutter_zpl_printer/Frameworks/libusb.xcframework/macos-arm64_x86_64/libusb-1.0.dylib'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end

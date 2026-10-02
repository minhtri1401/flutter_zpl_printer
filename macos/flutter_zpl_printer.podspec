#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_zpl_printer.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_zpl_printer'
  s.version          = '0.1.1'
  s.summary          = 'Flutter plugin for Zebra ZPL label printers (BLE, TCP, USB).'
  s.description      = <<-DESC
Discover, connect to, and print on Zebra ZPL label printers over Bluetooth LE, Wi-Fi/TCP, and USB.
                       DESC
  s.homepage         = 'https://github.com/minhtri1401/flutter_zpl_printer'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'minhtri1401' => 'https://github.com/minhtri1401' }

  s.source           = { :path => '.' }
  # Classes/Usb and Classes/UsbMessages.g.swift are symlinks into ../darwin/
  # so the iOS and macOS plugins share one Swift codebase.
  s.source_files = 'Classes/**/*.swift'

  # Bundle libusb.dylib for FFI. Path relative to this podspec.
  s.vendored_libraries = '../third_party/libusb/1.0.29/macos/libusb-1.0.dylib'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'flutter_zpl_printer_privacy' => ['Resources/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end

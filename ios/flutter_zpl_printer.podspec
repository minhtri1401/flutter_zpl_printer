Pod::Spec.new do |s|
  s.name             = 'flutter_zpl_printer'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for Zebra ZPL printers'
  s.description      = <<-DESC
Integrates Zebra Link-OS SDK for printer discovery, connection, and ZPL printing.
                       DESC
  s.homepage         = 'https://github.com/minhtri1401/flutter_zpl_printer'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'minhtri1401' => 'https://github.com/minhtri1401' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'

  # Zebra Link-OS SDK (static library + headers)
  s.vendored_libraries = 'Frameworks/libZSDK_API.a'
  s.frameworks         = 'ExternalAccessory'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/Frameworks/include'
  }
  s.swift_version = '5.0'
end

#if os(iOS)
  import Flutter
  import UIKit
#elseif os(macOS)
  import Cocoa
  import FlutterMacOS
#endif

public class FlutterZplPrinterPlugin: NSObject, FlutterPlugin {
  private static var hotplugHandler: UsbHotplugStreamHandler?

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #elseif os(macOS)
      let messenger = registrar.messenger
    #endif

    let channel = FlutterMethodChannel(name: "flutter_zpl_printer", binaryMessenger: messenger)
    let instance = FlutterZplPrinterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    // USB HostApi (Pigeon). On iOS every call returns USB_UNSUPPORTED.
    UsbHostApiSetup.setUp(binaryMessenger: messenger, api: UsbHostApiImpl())

    // USB hot-plug EventChannel. A no-op on iOS.
    let handler = UsbHotplugStreamHandler()
    hotplugHandler = handler
    let eventChannel = FlutterEventChannel(
      name: "com.zebra.flutter_zpl_printer/usb/hotplug",
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(handler)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      #if os(iOS)
        result("iOS " + UIDevice.current.systemVersion)
      #elseif os(macOS)
        result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
      #endif
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

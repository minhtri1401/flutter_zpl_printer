import Flutter
import UIKit

public class FlutterZplPrinterPlugin: NSObject, FlutterPlugin {
  private static var hotplugHandler: UsbHotplugStreamHandler?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_zpl_printer", binaryMessenger: registrar.messenger())
    let instance = FlutterZplPrinterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    // USB HostApi stub on iOS — every call returns USB_UNSUPPORTED.
    UsbHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: UsbHostApiImpl())

    // Hot-plug stream handler is a no-op on iOS.
    let handler = UsbHotplugStreamHandler()
    hotplugHandler = handler
    let eventChannel = FlutterEventChannel(
      name: "com.zebra.flutter_zpl_printer/usb/hotplug",
      binaryMessenger: registrar.messenger()
    )
    eventChannel.setStreamHandler(handler)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

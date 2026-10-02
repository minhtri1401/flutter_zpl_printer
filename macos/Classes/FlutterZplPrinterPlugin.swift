import Cocoa
import FlutterMacOS

public class FlutterZplPrinterPlugin: NSObject, FlutterPlugin {
  private static var hotplugHandler: UsbHotplugStreamHandler?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_zpl_printer", binaryMessenger: registrar.messenger)
    let instance = FlutterZplPrinterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    // USB HostApi (Pigeon).
    UsbHostApiSetup.setUp(binaryMessenger: registrar.messenger, api: UsbHostApiImpl())

    // USB hot-plug EventChannel.
    let handler = UsbHotplugStreamHandler()
    hotplugHandler = handler
    let eventChannel = FlutterEventChannel(
      name: "com.zebra.flutter_zpl_printer/usb/hotplug",
      binaryMessenger: registrar.messenger
    )
    eventChannel.setStreamHandler(handler)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

import Flutter

public class FlutterZplPrinterPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let flutterApi = PrinterFlutterApi(binaryMessenger: messenger)
        let impl = PrinterHostApiImpl(flutterApi: flutterApi)
        PrinterHostApiSetup.setUp(binaryMessenger: messenger, api: impl)
    }
}

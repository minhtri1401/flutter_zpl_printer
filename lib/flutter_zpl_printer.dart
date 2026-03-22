import 'dart:async';

import 'src/pigeon.g.dart';

export 'src/pigeon.g.dart' show PrinterDevice, PrinterStatus, ConnectionType;

class FlutterZplPrinter {
  FlutterZplPrinter() {
    PrinterFlutterApi.setUp(_flutterApiHandler);
  }

  final PrinterHostApi _hostApi = PrinterHostApi();
  final _PrinterFlutterApiHandler _flutterApiHandler =
      _PrinterFlutterApiHandler();

  /// Stream of printers found during discovery.
  Stream<PrinterDevice> get onPrinterFound =>
      _flutterApiHandler.printerFoundController.stream;

  /// Emits when discovery completes.
  Stream<void> get onDiscoveryCompleted =>
      _flutterApiHandler.discoveryCompletedController.stream;

  /// Start scanning for printers (Wi-Fi + Bluetooth).
  Future<void> startDiscovery() => _hostApi.startDiscovery();

  /// Stop scanning for printers.
  void stopDiscovery() => _hostApi.stopDiscovery();

  /// Connect to printer at [address] using [type].
  Future<void> connect(String address, ConnectionType type) =>
      _hostApi.connect(address, type);

  /// Disconnect current printer.
  void disconnect() => _hostApi.disconnect();

  /// Send ZPL payload to connected printer.
  Future<void> printZpl(String zplPayload) => _hostApi.printZpl(zplPayload);

  /// Get current printer status.
  Future<PrinterStatus> getStatus() => _hostApi.getStatus();

  /// Get all printer settings as key-value pairs.
  Future<Map<String, String>> getSettings() async {
    final settings = await _hostApi.getSettings();
    return {
      for (final e in settings.entries)
        if (e.key != null && e.value != null) e.key!: e.value!,
    };
  }

  /// Clean up stream controllers.
  void dispose() {
    _flutterApiHandler.dispose();
  }
}

class _PrinterFlutterApiHandler implements PrinterFlutterApi {
  final printerFoundController = StreamController<PrinterDevice>.broadcast();
  final discoveryCompletedController = StreamController<void>.broadcast();

  @override
  void onPrinterFound(PrinterDevice printer) {
    printerFoundController.add(printer);
  }

  @override
  void onDiscoveryCompleted() {
    discoveryCompletedController.add(null);
  }

  void dispose() {
    printerFoundController.close();
    discoveryCompletedController.close();
  }
}

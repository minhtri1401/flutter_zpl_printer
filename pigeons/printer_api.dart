import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/pigeon.g.dart',
  swiftOut: 'ios/Classes/PigeonGenerated.g.swift',
  kotlinOut:
      'android/src/main/kotlin/com/example/flutter_zpl_printer/PigeonGenerated.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.example.flutter_zpl_printer'),
  swiftOptions: SwiftOptions(),
))
enum ConnectionType {
  bluetooth,
  wifi,
}

class PrinterDevice {
  PrinterDevice({
    required this.name,
    required this.address,
    required this.type,
  });

  String name;
  String address;
  ConnectionType type;
}

class PrinterStatus {
  PrinterStatus({
    required this.isReadyToPrint,
    required this.isHeadOpen,
    required this.isHeadCold,
    required this.isHeadTooHot,
    required this.isPaperOut,
    required this.isRibbonOut,
    required this.isReceiveBufferFull,
    required this.isPaused,
    required this.isPartialFormatInProgress,
    required this.labelLengthInDots,
    required this.numberOfFormatsInReceiveBuffer,
    required this.labelsRemainingInBatch,
  });

  bool isReadyToPrint;
  bool isHeadOpen;
  bool isHeadCold;
  bool isHeadTooHot;
  bool isPaperOut;
  bool isRibbonOut;
  bool isReceiveBufferFull;
  bool isPaused;
  bool isPartialFormatInProgress;
  int labelLengthInDots;
  int numberOfFormatsInReceiveBuffer;
  int labelsRemainingInBatch;
}

@HostApi()
abstract class PrinterHostApi {
  @async
  void startDiscovery();

  void stopDiscovery();

  @async
  void connect(String address, ConnectionType type);

  void disconnect();

  @async
  void printZpl(String zplPayload);

  @async
  PrinterStatus getStatus();

  @async
  Map<String?, String?> getSettings();
}

@FlutterApi()
abstract class PrinterFlutterApi {
  void onPrinterFound(PrinterDevice printer);
  void onDiscoveryCompleted();
}

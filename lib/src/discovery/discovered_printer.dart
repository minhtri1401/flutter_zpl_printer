import '../connection/ble_connection.dart';
import '../connection/connection.dart';
import '../connection/connection_config.dart';
import '../connection/tcp_connection.dart';
import '../connection/usb_connection.dart';
import '../connection/usb_device_address.dart';
import 'zebra_name_parser.dart';

/// Transport type for a discovered printer.
///
/// Ordinals are persisted (see consumer apps' saved-printer stores), so
/// values must never be reordered — only appended.
enum ConnectionType {
  tcp, // 0
  ble, // 1
  usb, // 2 — appended for USB transport
}

/// Ergonomic helpers so consumers don't write exhaustive switches on
/// [ConnectionType] throughout their code — future transport additions only
/// touch this extension.
extension ConnectionTypeX on ConnectionType {
  String get displayName => switch (this) {
        ConnectionType.tcp => 'Wi-Fi',
        ConnectionType.ble => 'Bluetooth',
        ConnectionType.usb => 'USB',
      };

  bool get isWired => this == ConnectionType.usb;
  bool get isWireless => !isWired;
}

/// A printer found during discovery.
class DiscoveredPrinter {
  /// IP address (TCP) or BLE device ID.
  final String address;

  /// Friendly name if available.
  final String? name;

  /// How the printer was discovered.
  final ConnectionType connectionType;

  /// TCP port (only for TCP printers).
  final int port;

  /// Raw metadata from discovery response.
  final Map<String, String> discoveryData;

  DiscoveredPrinter({
    required this.address,
    this.name,
    required this.connectionType,
    this.port = 9100,
    this.discoveryData = const {},
  });

  /// Display-quality printer name.
  ///
  /// USB-sourced printers populate `discoveryData['model']` + `['serial']`
  /// from descriptor strings — we use them directly. Other sources fall back
  /// to parsing [name] via the Zebra UDP blob regex.
  String get friendlyName {
    final m = model;
    final s = serial;
    if (m != null && s != null) return '$m ($s)';
    return friendlyZebraName(name);
  }

  /// Printer model. USB: from iProduct descriptor (populated in
  /// `discoveryData['model']`). Other: parsed from the Zebra advanced-discovery
  /// blob via [extractZebraModel].
  String? get model => discoveryData['model'] ?? extractZebraModel(name);

  /// Printer serial. USB: from iSerialNumber descriptor. Other: parsed from
  /// [name] via [extractZebraSerial].
  String? get serial => discoveryData['serial'] ?? extractZebraSerial(name);

  /// Create a [Connection] instance for this printer.
  Connection createConnection({ConnectionConfig? config}) {
    switch (connectionType) {
      case ConnectionType.tcp:
        return TcpConnection(address, port, config: config);
      case ConnectionType.ble:
        return BleConnection(address, config: config);
      case ConnectionType.usb:
        return UsbConnection(UsbDeviceAddress.parse(address), config: config);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredPrinter &&
          address == other.address &&
          connectionType == other.connectionType;

  @override
  int get hashCode => address.hashCode ^ connectionType.hashCode;

  @override
  String toString() => 'DiscoveredPrinter($connectionType, $address, $name)';
}

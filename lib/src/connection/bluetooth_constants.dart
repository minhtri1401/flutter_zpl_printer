/// Zebra BLE constants from SDK's `BluetoothLeZebraConnectorImpl`.
class ZebraBluetoothConstants {
  ZebraBluetoothConstants._();

  /// Zebra BLE advertisement service UUID — short 16-bit form.
  /// Use this for BLE scan filters so native APIs (iOS CBCentralManager,
  /// Android ScanFilter) match the `0xFE79` UUID in the printer's AD type 0x03
  /// without needing to expand to the full 128-bit form.
  static const zebraBleServiceUuidShort = 'fe79';

  /// Zebra BLE service UUID — full 128-bit form for GATT connection.
  /// (0xFE79 expanded via Bluetooth Base UUID: 0000xxxx-0000-1000-8000-00805f9b34fb)
  static const zebraBleServiceUuid = '0000fe79-0000-1000-8000-00805f9b34fb';

  /// Characteristic UUID: data FROM printer (read/notify).
  static const dataFromPrinterCharUuid = '38eb4a81-c570-11e3-9507-0002a5d5c51b';

  /// Characteristic UUID: data TO printer (write).
  static const dataToPrinterCharUuid = '38eb4a82-c570-11e3-9507-0002a5d5c51b';

  /// Characteristic UUID: status FROM printer (read/notify, JSON/SGD responses).
  static const statusFromPrinterCharUuid =
      '38eb4a83-c570-11e3-9507-0002a5d5c51b';

  /// Characteristic UUID: status TO printer (write, SGD/status commands).
  static const statusToPrinterCharUuid = '38eb4a84-c570-11e3-9507-0002a5d5c51b';

  /// Zebra BLE data service UUID (contains print + status characteristics).
  static const zebraBleDataServiceUuid = '38eb4a80-c570-11e3-9507-0002a5d5c51b';

  /// Default MTU to request during negotiation.
  static const defaultMtu = 512;

  /// BLE default MTU before negotiation.
  static const bleDefaultMtu = 20;

  /// Delay after GATT connect before I/O (ms). SDK: `Sleeper.sleep(1000L)`.
  static const postConnectDelayMs = 1000;

  /// Delay before disconnect to let printer finish (ms). SDK: `Sleeper.sleep(5000L)`.
  static const preCloseDelayMs = 5000;

  /// BLE ATT overhead bytes subtracted from MTU for payload.
  static const bleAttOverhead = 3;
}

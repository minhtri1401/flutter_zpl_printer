/// Pure-Dart library for Zebra label printers via BLE, TCP, and USB.
///
/// No Link-OS SDK dependency. Communicates directly using Zebra's native
/// printer protocols (SGD, ZPL status, BLE characteristics).
library;

// Label building (re-exported so one import covers building and printing).
export 'package:flutter_zpl_generator/flutter_zpl_generator.dart';

// Exceptions
export 'src/exceptions/connection_exception.dart';

// Connection layer
export 'src/connection/connection.dart';
export 'src/connection/connection_config.dart';
export 'src/connection/tcp_connection.dart';
export 'src/connection/ble_connection.dart';
export 'src/connection/bluetooth_constants.dart';
export 'src/connection/multichannel_tcp_connection.dart';
export 'src/connection/response_validators.dart';
export 'src/connection/reconnectable_connection.dart';
export 'src/connection/multichannel_ble_connection.dart';
export 'src/connection/usb_connection.dart';
export 'src/connection/usb_device_address.dart';

// Discovery layer
export 'src/discovery/discovered_printer.dart';
export 'src/discovery/network_discovery.dart';
export 'src/discovery/ble_discovery.dart';
export 'src/discovery/discovery_service.dart';
export 'src/discovery/usb_discovery.dart';
export 'src/discovery/zebra_name_parser.dart';

// Platform (public types only — hotplug stream)
export 'src/platform/usb_hotplug_stream.dart'
    show UsbHotplugEvent, UsbHotplugType, UsbHotplugStream;

// Printer operations
export 'src/printer/sgd.dart';
export 'src/printer/printer_status.dart';
export 'src/printer/printer_language.dart';
export 'src/printer/zebra_printer.dart';
export 'src/printer/zebra_printer_link_os.dart';
export 'src/printer/file_util.dart';
export 'src/printer/format_util.dart';
export 'src/printer/font_util.dart';
export 'src/printer/alert_util.dart';
export 'src/printer/zpl_sanitizer.dart';
export 'src/printer/profile_util.dart';
export 'src/printer/profile_constants.dart';
export 'src/printer/firmware_util.dart';

// Graphics
export 'src/graphics/grf_encoder.dart';
export 'src/graphics/z64_compressor.dart';
export 'src/graphics/graphics_util.dart';

// Models
export 'src/models/printer_print_mode.dart';
export 'src/models/storage_info.dart';
export 'src/models/printer_object.dart';
export 'src/models/field_description.dart';
export 'src/models/link_os_version.dart';
export 'src/models/printer_alert.dart';
export 'src/models/printer_profile.dart';
export 'src/models/printer_metadata_key.dart';
export 'src/models/printer_sgd_key.dart';

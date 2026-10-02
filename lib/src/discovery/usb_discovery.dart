import 'dart:async';

import '../connection/usb_device_address.dart';
import '../platform/usb_hotplug_stream.dart';
import '../platform/usb_messages.g.dart';
import '../platform/usb_platform.dart';
import '../platform/usb_platform_composite.dart';
import 'discovered_printer.dart';

/// USB discovery source.
///
/// Emits a finite stream of [DiscoveredPrinter]s from a single platform
/// enumeration pass. Feeds [DiscoveryService.discoverAll] alongside UDP
/// broadcast/multicast and BLE. One-shot — use [hotplugStream] for live
/// attach/detach updates.
class UsbDiscovery {
  UsbDiscovery._();

  /// Production entry point. Wires to the default [UsbPlatform] composite.
  ///
  /// The [timeout] is currently ignored — USB enumeration is synchronous,
  /// completing in milliseconds on all platforms.
  static Stream<DiscoveredPrinter> enumerate({
    Duration timeout = const Duration(seconds: 2),
    bool includeNonZebra = false,
  }) =>
      enumerateWith(
        platform: _defaultPlatform(),
        includeNonZebra: includeNonZebra,
      );

  /// Test-visible variant that accepts an injected [UsbPlatform].
  ///
  /// Wraps the platform call in a stream so per-source errors surface through
  /// [DiscoveryService.mergeSources]' `onError` handler and don't crash the
  /// merged pipeline.
  static Stream<DiscoveredPrinter> enumerateWith({
    required UsbPlatform platform,
    bool includeNonZebra = false,
  }) {
    final filter = UsbEnumerateFilter(
      vendorId: includeNonZebra ? null : UsbDeviceAddress.zebraVendorId,
      includeDescriptorStrings: true,
    );

    final controller = StreamController<DiscoveredPrinter>();

    () async {
      try {
        final records = await platform.enumerate(filter);
        for (final r in records) {
          if (controller.isClosed) return;
          controller.add(_toDiscoveredPrinter(r));
        }
      } catch (e, s) {
        if (!controller.isClosed) controller.addError(e, s);
      } finally {
        if (!controller.isClosed) await controller.close();
      }
    }();

    return controller.stream;
  }

  /// Broadcast hot-plug stream. Shorthand for [UsbHotplugStream.events].
  static Stream<UsbHotplugEvent> hotplugStream() => UsbHotplugStream.events();

  static DiscoveredPrinter _toDiscoveredPrinter(UsbDeviceRecord r) {
    final addr = UsbDeviceAddress(
      vendorId: r.vendorId,
      productId: r.productId,
      serialNumber: r.serialNumber,
    );
    return DiscoveredPrinter(
      address: addr.encode(),
      name: r.product,
      connectionType: ConnectionType.usb,
      port: 0,
      discoveryData: {
        'vendorId':
            r.vendorId.toRadixString(16).toUpperCase().padLeft(4, '0'),
        'productId':
            r.productId.toRadixString(16).toUpperCase().padLeft(4, '0'),
        if (r.manufacturer != null) 'manufacturer': r.manufacturer!,
        if (r.product != null) 'model': r.product!,
        if (r.serialNumber != null) 'serial': r.serialNumber!,
        'path': r.path,
        if (r.interfaceNumber != null)
          'interfaceNumber': '${r.interfaceNumber}',
        if (r.bulkInEndpoint != null)
          'bulkInEndpoint': '0x${r.bulkInEndpoint!.toRadixString(16)}',
        if (r.bulkOutEndpoint != null)
          'bulkOutEndpoint': '0x${r.bulkOutEndpoint!.toRadixString(16)}',
        if (r.wMaxPacketSizeOut != null)
          'wMaxPacketSize': '${r.wMaxPacketSizeOut}',
        if (r.driverBinding != null) 'driverBinding': r.driverBinding!,
      },
    );
  }

  /// Process-singleton composite platform. Tests inject via [enumerateWith].
  static UsbPlatform _defaultPlatform() =>
      _sharedPlatform ??= UsbPlatformComposite();

  static UsbPlatform? _sharedPlatform;
}

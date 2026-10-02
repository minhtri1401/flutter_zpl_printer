import 'dart:async';

import 'ble_discovery.dart';
import 'discovered_printer.dart';
import 'network_discovery.dart';
import 'usb_discovery.dart';

/// Transports that [DiscoveryService.discoverAll] can enable.
///
/// Declaration order reflects priority — USB (wired) first, then LAN UDP,
/// then BLE (radio). The priority used at connect-time lives in the
/// consumer app's `TransportPolicy.orderFor`; this enum simply lists what's
/// available.
///
/// No ordinal is persisted for this enum, so reordering here is safe.
enum DiscoveryTransport {
  usb, // tier 1 — wired
  udpBroadcast,
  udpMulticast,
  ble, // tier 3 — radio
}

/// Unified discovery service combining all transport-specific discovery methods.
class DiscoveryService {
  DiscoveryService._();

  /// Discover printers across all specified transports.
  ///
  /// Merges USB, UDP broadcast, UDP multicast, and BLE sources via
  /// [mergeSources]. Deduplicates by address. Per-source failures
  /// (e.g. USB enumeration when libusb isn't loaded, [NetworkDiscovery]
  /// when Wi-Fi is off) are swallowed so the remaining transports keep
  /// producing results.
  static Stream<DiscoveredPrinter> discoverAll({
    Set<DiscoveryTransport> transports = const {
      DiscoveryTransport.usb,
      DiscoveryTransport.udpBroadcast,
      DiscoveryTransport.udpMulticast,
      DiscoveryTransport.ble,
    },
    Duration timeout = const Duration(seconds: 10),
  }) {
    final sources = <Stream<DiscoveredPrinter>>[
      if (transports.contains(DiscoveryTransport.usb))
        UsbDiscovery.enumerate(timeout: timeout),
      if (transports.contains(DiscoveryTransport.udpBroadcast))
        NetworkDiscovery.discover(timeout: timeout),
      if (transports.contains(DiscoveryTransport.udpMulticast))
        NetworkDiscovery.multicast(timeout: timeout),
      if (transports.contains(DiscoveryTransport.ble))
        BleDiscovery.discoverZebra(timeout: timeout),
    ];
    return mergeSources(sources);
  }

  /// Merge multiple discovery streams into one, deduplicating by
  /// [DiscoveredPrinter.address] and tolerating per-source errors.
  ///
  /// Exposed for testing — production callers use [discoverAll].
  static Stream<DiscoveredPrinter> mergeSources(
    List<Stream<DiscoveredPrinter>> sources,
  ) {
    final controller = StreamController<DiscoveredPrinter>();
    final seen = <String>{};
    final subscriptions = <StreamSubscription>[];

    void addPrinter(DiscoveredPrinter printer) {
      if (seen.contains(printer.address)) return;
      seen.add(printer.address);
      if (!controller.isClosed) controller.add(printer);
    }

    var activeSources = sources.length;

    void onSourceDone() {
      activeSources--;
      if (activeSources <= 0 && !controller.isClosed) {
        controller.close();
      }
    }

    for (final source in sources) {
      subscriptions.add(
        source.listen(
          addPrinter,
          // Per-source errors must not kill the merged stream — other
          // transports may still produce results. Swallow and treat the
          // failing source as if it finished with no results.
          //
          // With cancelOnError:true the source subscription is cancelled and
          // its onDone never fires, so decrement activeSources here.
          onError: (Object _) => onSourceDone(),
          onDone: onSourceDone,
          cancelOnError: true,
        ),
      );
    }

    if (activeSources == 0) {
      controller.close();
    }

    controller.onCancel = () {
      for (final sub in subscriptions) {
        sub.cancel();
      }
    };

    return controller.stream;
  }

  /// Discover printers on the local network only (TCP/WiFi).
  static Stream<DiscoveredPrinter> discoverNetwork({
    Duration timeout = const Duration(seconds: 6),
  }) =>
      NetworkDiscovery.discover(timeout: timeout);

  /// Discover printers via BLE only.
  static Stream<DiscoveredPrinter> discoverBle({
    Duration timeout = const Duration(seconds: 30),
  }) =>
      BleDiscovery.discover(timeout: timeout);

  /// Discover printers on a specific subnet via directed broadcast.
  static Stream<DiscoveredPrinter> discoverSubnet(
    String subnetPrefix, {
    Duration timeout = const Duration(seconds: 6),
  }) =>
      NetworkDiscovery.directedBroadcast(subnetPrefix, timeout: timeout);

  /// Discover printers via multicast (cross-subnet capable).
  static Stream<DiscoveredPrinter> discoverMulticast({
    Duration timeout = const Duration(seconds: 6),
  }) =>
      NetworkDiscovery.multicast(timeout: timeout);
}

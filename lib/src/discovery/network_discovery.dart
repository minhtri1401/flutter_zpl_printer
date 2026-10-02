import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'discovered_printer.dart';

/// Network discovery for Zebra printers using UDP broadcast (port 4201).
///
/// Mirrors SDK's `BroadcastA.java` discovery protocol.
class NetworkDiscovery {
  NetworkDiscovery._();

  /// UDP discovery port used by Zebra printers.
  static const int _discoveryPort = 4201;

  /// Advanced discovery packet from SDK's `BroadcastA`.
  static final Uint8List _advancedDiscoveryPacket = Uint8List.fromList(
    [0x2E, 0x2C, 0x3A, 0x01, 0x00, 0x00, 0x00, 0x01, 0xA4, 0xED, 0x00, 0x00, 0x00],
  );

  /// Discover Zebra printers on the local network via UDP broadcast.
  ///
  /// Returns a stream of discovered printers. Auto-stops after [timeout].
  static Stream<DiscoveredPrinter> discover({
    Duration timeout = const Duration(seconds: 6),
  }) {
    late StreamController<DiscoveredPrinter> controller;
    RawDatagramSocket? socket;
    Timer? timer;
    final seen = <String>{};

    controller = StreamController<DiscoveredPrinter>(
      onListen: () async {
        try {
          socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
          socket!.broadcastEnabled = true;
          // ignore: avoid_print
          print('[network-discovery] broadcast bound on '
              '${socket!.address.address}:${socket!.port}, '
              'sending to 255.255.255.255:$_discoveryPort');

          final sent = socket!.send(
            _advancedDiscoveryPacket,
            InternetAddress('255.255.255.255'),
            _discoveryPort,
          );
          // ignore: avoid_print
          print('[network-discovery] broadcast send returned $sent bytes '
              '(packet size ${_advancedDiscoveryPacket.length})');

          socket!.listen((event) {
            if (event == RawSocketEvent.read) {
              final datagram = socket!.receive();
              if (datagram == null) return;

              final address = datagram.address.address;
              // ignore: avoid_print
              print('[network-discovery] broadcast reply from $address '
                  '(${datagram.data.length} bytes)');
              if (seen.contains(address)) return;
              seen.add(address);

              final printer = _parseResponse(datagram);
              if (printer != null) {
                controller.add(printer);
              }
            }
          });

          // Auto-stop after timeout
          timer = Timer(timeout, () {
            // ignore: avoid_print
            print('[network-discovery] broadcast timeout after '
                '${timeout.inSeconds}s, replies received: ${seen.length}');
            socket?.close();
            controller.close();
          });
        } catch (e) {
          // ignore: avoid_print
          print('[network-discovery] broadcast setup failed: $e');
          controller.addError(e);
          controller.close();
        }
      },
      onCancel: () {
        timer?.cancel();
        socket?.close();
      },
    );

    return controller.stream;
  }

  /// Discover printers on a specific subnet via directed broadcast.
  ///
  /// Sends discovery packet to `{subnetPrefix}.255:4201`.
  /// Only discovers printers on the specified `/24` subnet.
  ///
  /// Example: `directedBroadcast('192.168.1')` sends to `192.168.1.255`.
  static Stream<DiscoveredPrinter> directedBroadcast(
    String subnetPrefix, {
    Duration timeout = const Duration(seconds: 6),
  }) {
    if (!RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(subnetPrefix)) {
      throw ArgumentError.value(
          subnetPrefix, 'subnetPrefix', 'Expected format: X.Y.Z');
    }

    late StreamController<DiscoveredPrinter> controller;
    RawDatagramSocket? socket;
    Timer? timer;
    final seen = <String>{};

    controller = StreamController<DiscoveredPrinter>(
      onListen: () async {
        try {
          socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
          socket!.broadcastEnabled = true;

          socket!.send(
            _advancedDiscoveryPacket,
            InternetAddress('$subnetPrefix.255'),
            _discoveryPort,
          );

          socket!.listen((event) {
            if (event == RawSocketEvent.read) {
              final datagram = socket!.receive();
              if (datagram == null) return;
              final address = datagram.address.address;
              if (seen.contains(address)) return;
              seen.add(address);
              final printer = _parseResponse(datagram);
              if (printer != null) controller.add(printer);
            }
          });

          timer = Timer(timeout, () {
            socket?.close();
            controller.close();
          });
        } catch (e) {
          controller.addError(e);
          controller.close();
        }
      },
      onCancel: () {
        timer?.cancel();
        socket?.close();
      },
    );
    return controller.stream;
  }

  /// Discover printers via multicast (can cross router boundaries).
  ///
  /// Sends to multicast group `224.0.1.55:4201`.
  /// Note: iOS may require NetworkExtension entitlement for multicast.
  static Stream<DiscoveredPrinter> multicast({
    Duration timeout = const Duration(seconds: 6),
    int ttl = 0,
  }) {
    late StreamController<DiscoveredPrinter> controller;
    RawDatagramSocket? socket;
    Timer? timer;
    final seen = <String>{};
    const multicastGroup = '224.0.1.55';

    controller = StreamController<DiscoveredPrinter>(
      onListen: () async {
        try {
          socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
          // ignore: avoid_print
          print('[network-discovery] multicast bound on '
              '${socket!.address.address}:${socket!.port}, '
              'target $multicastGroup:$_discoveryPort');

          try {
            socket!.joinMulticast(InternetAddress(multicastGroup));
            // ignore: avoid_print
            print('[network-discovery] multicast join OK');
          } catch (e) {
            // joinMulticast may fail on iOS; continue with send-only
            // ignore: avoid_print
            print('[network-discovery] multicast join failed '
                '(continuing send-only): $e');
          }

          if (ttl > 0) socket!.multicastHops = ttl;

          final sent = socket!.send(
            _advancedDiscoveryPacket,
            InternetAddress(multicastGroup),
            _discoveryPort,
          );
          // ignore: avoid_print
          print('[network-discovery] multicast send returned $sent bytes');

          socket!.listen((event) {
            if (event == RawSocketEvent.read) {
              final datagram = socket!.receive();
              if (datagram == null) return;
              final address = datagram.address.address;
              // ignore: avoid_print
              print('[network-discovery] multicast reply from $address '
                  '(${datagram.data.length} bytes)');
              if (seen.contains(address)) return;
              seen.add(address);
              final printer = _parseResponse(datagram);
              if (printer != null) controller.add(printer);
            }
          });

          timer = Timer(timeout, () {
            // ignore: avoid_print
            print('[network-discovery] multicast timeout after '
                '${timeout.inSeconds}s, replies received: ${seen.length}');
            socket?.close();
            controller.close();
          });
        } catch (e) {
          // ignore: avoid_print
          print('[network-discovery] multicast setup failed: $e');
          controller.addError(e);
          controller.close();
        }
      },
      onCancel: () {
        timer?.cancel();
        socket?.close();
      },
    );
    return controller.stream;
  }

  /// Discover printers by probing each IP in a subnet via TCP port 9100.
  ///
  /// Slowest but most reliable -- works even when UDP is blocked.
  /// Probes IPs in batches of 20 to avoid socket exhaustion.
  static Stream<DiscoveredPrinter> subnetSearch(
    String subnetPrefix, {
    int startIp = 1,
    int endIp = 254,
    Duration timeout = const Duration(seconds: 15),
    Duration probeTimeout = const Duration(seconds: 1),
  }) {
    if (!RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(subnetPrefix)) {
      throw ArgumentError.value(
          subnetPrefix, 'subnetPrefix', 'Expected format: X.Y.Z');
    }

    late StreamController<DiscoveredPrinter> controller;
    bool cancelled = false;

    controller = StreamController<DiscoveredPrinter>(
      onListen: () async {
        // Enforce overall timeout regardless of probe progress
        final overallTimer = Timer(timeout, () {
          cancelled = true;
          if (!controller.isClosed) controller.close();
        });
        try {
          const batchSize = 20;
          for (int i = startIp; i <= endIp && !cancelled; i += batchSize) {
            final batchEnd = (i + batchSize - 1).clamp(startIp, endIp);
            final futures = <Future>[];

            for (int ip = i; ip <= batchEnd; ip++) {
              final host = '$subnetPrefix.$ip';
              futures.add(_probeHost(host, probeTimeout).then((found) {
                if (found && !cancelled && !controller.isClosed) {
                  controller.add(DiscoveredPrinter(
                    address: host,
                    connectionType: ConnectionType.tcp,
                    port: 9100,
                  ));
                }
              }));
            }
            await Future.wait(futures);
          }
        } catch (e) {
          if (!controller.isClosed) controller.addError(e);
        } finally {
          overallTimer.cancel();
          if (!controller.isClosed) controller.close();
        }
      },
      onCancel: () {
        cancelled = true;
      },
    );
    return controller.stream;
  }

  /// Probe a host by attempting TCP connect to port 9100.
  static Future<bool> _probeHost(String host, Duration timeout) async {
    try {
      final socket = await Socket.connect(host, 9100, timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Parse a UDP discovery response datagram.
  /// Extracts printer address; full metadata decoding is a V2 enhancement.
  static DiscoveredPrinter? _parseResponse(Datagram datagram) {
    final address = datagram.address.address;
    String? name;

    // Try to extract printer name from response data (ASCII portion)
    try {
      final data = datagram.data;
      if (data.length > 20) {
        final ascii = data
            .where((b) => b >= 32 && b < 127)
            .map((b) => String.fromCharCode(b))
            .join();
        if (ascii.isNotEmpty) {
          name = ascii.length > 50 ? ascii.substring(0, 50) : ascii;
        }
      }
    } catch (_) {
      // Ignore parse errors; address alone is sufficient
    }

    return DiscoveredPrinter(
      address: address,
      name: name,
      connectionType: ConnectionType.tcp,
      port: 9100,
    );
  }
}

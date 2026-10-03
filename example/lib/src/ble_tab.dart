import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';
import 'package:permission_handler/permission_handler.dart';

import 'common.dart';

/// Bluetooth LE: scan for Zebra printers, tap one to connect.
class BleTab extends StatefulWidget {
  const BleTab({super.key});

  @override
  State<BleTab> createState() => _BleTabState();
}

class _BleTabState extends State<BleTab> with AutomaticKeepAliveClientMixin {
  final _printers = <DiscoveredPrinter>[];
  StreamSubscription<DiscoveredPrinter>? _scan;
  bool _scanning = false;

  @override
  bool get wantKeepAlive => true;

  /// Android asks for Bluetooth permissions at runtime. iOS, macOS, and
  /// Windows show their own system prompt the first time Bluetooth is used.
  Future<bool> _ensurePermissions() async {
    if (!Platform.isAndroid) return true;
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    final bluetoothGranted =
        statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted;
    return bluetoothGranted || statuses[Permission.location]!.isGranted;
  }

  Future<void> _startScan() async {
    if (!await _ensurePermissions()) {
      if (mounted) showError(context, 'Bluetooth permission denied.');
      return;
    }
    await _scan?.cancel();
    setState(() {
      _printers.clear();
      _scanning = true;
    });

    // discoverZebra filters on Zebra's advertised BLE service.
    _scan = BleDiscovery.discoverZebra(timeout: const Duration(seconds: 15))
        .listen(
          (printer) {
            if (_printers.contains(printer)) return;
            setState(() => _printers.add(printer));
          },
          onError: (Object e) {
            if (mounted) showError(context, e);
          },
          onDone: () {
            if (mounted) setState(() => _scanning = false);
          },
        );
  }

  Future<void> _stopScan() async {
    await _scan?.cancel();
    _scan = null;
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _connect(DiscoveredPrinter printer) async {
    await _stopScan();
    if (!mounted) return;
    // Equivalent to BleConnection(printer.address).
    await connectAndOpen(
      context,
      printer.createConnection(),
      title: printer.friendlyName,
    );
  }

  @override
  void dispose() {
    _scan?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _scanning
                      ? 'Scanning for Zebra printers…'
                      : '${_printers.length} found',
                ),
              ),
              _scanning
                  ? OutlinedButton.icon(
                      onPressed: _stopScan,
                      icon: const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      label: const Text('Stop'),
                    )
                  : FilledButton.icon(
                      onPressed: _startScan,
                      icon: const Icon(Icons.bluetooth_searching),
                      label: const Text('Scan'),
                    ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _printers.isEmpty
              ? const EmptyHint(
                  icon: Icons.bluetooth,
                  message:
                      'Turn the printer on, then tap Scan.\n'
                      'Printers need Bluetooth 4.0 (BLE) or later.',
                )
              : ListView(
                  children: [
                    for (final p in _printers)
                      PrinterTile(printer: p, onTap: () => _connect(p)),
                  ],
                ),
        ),
      ],
    );
  }
}

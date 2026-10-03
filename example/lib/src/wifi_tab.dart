import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

import 'common.dart';

/// Wi-Fi / Ethernet: UDP discovery on the local network, or connect by IP.
class WifiTab extends StatefulWidget {
  const WifiTab({super.key});

  @override
  State<WifiTab> createState() => _WifiTabState();
}

class _WifiTabState extends State<WifiTab> with AutomaticKeepAliveClientMixin {
  final _printers = <DiscoveredPrinter>[];
  final _ipController = TextEditingController();
  StreamSubscription<DiscoveredPrinter>? _scan;
  bool _scanning = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _startScan() async {
    await _scan?.cancel();
    setState(() {
      _printers.clear();
      _scanning = true;
    });

    // UDP broadcast + multicast on port 4201, merged and de-duplicated.
    _scan =
        DiscoveryService.discoverAll(
          transports: const {
            DiscoveryTransport.udpBroadcast,
            DiscoveryTransport.udpMulticast,
          },
          timeout: const Duration(seconds: 8),
        ).listen(
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

  Future<void> _connect(Connection connection, String title) async {
    await _scan?.cancel();
    if (mounted) setState(() => _scanning = false);
    if (!mounted) return;
    await connectAndOpen(context, connection, title: title);
  }

  void _connectManual() {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;
    FocusScope.of(context).unfocus();
    // Port 9100 is the raw ZPL port on every Zebra network printer.
    _connect(TcpConnection.zpl(ip), ip);
  }

  @override
  void dispose() {
    _scan?.cancel();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _connectManual(),
                  decoration: const InputDecoration(
                    labelText: 'Printer IP address',
                    hintText: '192.168.1.50',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _connectManual,
                child: const Text('Connect'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _scanning
                      ? 'Searching the local network…'
                      : '${_printers.length} found',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _scanning ? null : _startScan,
                icon: _scanning
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_find),
                label: const Text('Discover'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _printers.isEmpty
              ? const EmptyHint(
                  icon: Icons.wifi,
                  message:
                      'Tap Discover to find printers on this network,\n'
                      'or type the printer\'s IP address above.',
                )
              : ListView(
                  children: [
                    for (final p in _printers)
                      PrinterTile(
                        printer: p,
                        // Equivalent to TcpConnection(p.address, p.port).
                        onTap: () =>
                            _connect(p.createConnection(), p.friendlyName),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

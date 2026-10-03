import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

import 'common.dart';

/// USB: list attached Zebra printers and refresh on plug/unplug.
///
/// Experimental: USB code exists for macOS, Windows, and Android but hasn't
/// been confirmed working on any of them yet. iOS has no USB host access.
class UsbTab extends StatefulWidget {
  const UsbTab({super.key});

  @override
  State<UsbTab> createState() => _UsbTabState();
}

class _UsbTabState extends State<UsbTab> with AutomaticKeepAliveClientMixin {
  static final bool _supported =
      Platform.isMacOS || Platform.isWindows || Platform.isAndroid;

  final _printers = <DiscoveredPrinter>[];
  StreamSubscription<UsbHotplugEvent>? _hotplug;
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (!_supported) return;
    _refresh();
    _hotplug = UsbHotplugStream.events().listen(
      (_) => _refresh(),
      onError:
          (
            Object _,
          ) {}, // Hot-plug is best effort; the Refresh button still works.
    );
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    final found = <DiscoveredPrinter>[];
    try {
      await for (final printer in UsbDiscovery.enumerate()) {
        found.add(printer);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (!mounted) return;
    setState(() {
      _printers
        ..clear()
        ..addAll(found);
      _loading = false;
    });
  }

  Future<void> _connect(DiscoveredPrinter printer) async {
    // Equivalent to UsbConnection(UsbDeviceAddress.parse(printer.address)).
    // The address looks like usb://0A5F:0027/SERIAL.
    await connectAndOpen(
      context,
      printer.createConnection(),
      title: printer.friendlyName,
    );
  }

  @override
  void dispose() {
    _hotplug?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_supported) {
      return const EmptyHint(
        icon: Icons.usb_off,
        message:
            'USB printing is not available on this platform.\n'
            'iOS does not give apps USB host access. Use Bluetooth or Wi-Fi.',
      );
    }
    return Column(
      children: [
        if (Platform.isWindows)
          const NoticeCard(
            warning: true,
            message:
                'USB printing failed in our Windows testing, and the cause '
                'is not confirmed yet. Use Wi-Fi or Bluetooth on Windows for now. '
                'Plug/unplug is not detected on Windows: tap Refresh. '
                'See "Known issues → Windows USB" in the README.',
          ),
        if (Platform.isMacOS)
          const NoticeCard(
            message:
                'USB is experimental: it has not been tested with a printer on '
                'macOS yet. Bluetooth and Wi-Fi are tested and work.',
          ),
        if (Platform.isAndroid)
          const NoticeCard(
            message:
                'Android USB is untested, and this release does not bundle '
                'libusb-1.0.so, so connecting will fail. See "Known issues" in the README.',
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _loading
                      ? 'Looking for USB printers…'
                      : '${_printers.length} attached',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : _refresh,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _printers.isEmpty
              ? const EmptyHint(
                  icon: Icons.usb,
                  message: 'Plug in a Zebra printer, then tap Refresh.',
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

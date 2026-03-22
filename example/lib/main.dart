import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';
import 'package:flutter_zpl_generator/flutter_zpl_generator.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: PrinterExamplePage());
  }
}

class PrinterExamplePage extends StatefulWidget {
  const PrinterExamplePage({super.key});

  @override
  State<PrinterExamplePage> createState() => _PrinterExamplePageState();
}

class _PrinterExamplePageState extends State<PrinterExamplePage> {
  final _plugin = FlutterZplPrinter();
  final List<PrinterDevice> _devices = [];
  String _status = 'Idle';
  bool _isConnected = false;
  PrinterDevice? _connectedDevice;

  StreamSubscription<PrinterDevice>? _foundSub;
  StreamSubscription<void>? _completedSub;

  @override
  void initState() {
    super.initState();
    _foundSub = _plugin.onPrinterFound.listen((device) {
      if (mounted) setState(() => _devices.add(device));
    });
    _completedSub = _plugin.onDiscoveryCompleted.listen((_) {
      if (mounted) {
        setState(() => _status = 'Discovery done (${_devices.length} found)');
      }
    });
  }

  /// Request Bluetooth & location permissions required for printer discovery.
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final allGranted = statuses.values.every(
        (s) => s.isGranted || s.isLimited,
      );
      if (!allGranted) {
        setState(() => _status = 'Bluetooth/Location permissions denied');
        return false;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      if (!status.isGranted) {
        setState(() => _status = 'Bluetooth permission denied');
        return false;
      }
    }
    return true;
  }

  Future<void> _startDiscovery() async {
    if (!await _requestPermissions()) return;

    setState(() {
      _devices.clear();
      _status = 'Discovering...';
    });
    try {
      await _plugin.startDiscovery();
    } on PlatformException catch (e) {
      _setError(e);
    }
  }

  Future<void> _connect(PrinterDevice device) async {
    setState(() => _status = 'Connecting to ${device.name}...');
    try {
      await _plugin.connect(device.address, device.type);
      setState(() {
        _isConnected = true;
        _connectedDevice = device;
        _status = 'Connected to ${device.name}';
      });
    } on PlatformException catch (e) {
      _setError(e);
    }
  }

  Future<void> _disconnect() async {
    _plugin.disconnect();
    setState(() {
      _isConnected = false;
      _connectedDevice = null;
      _status = 'Disconnected';
    });
  }

  Future<void> _checkStatus() async {
    try {
      final status = await _plugin.getStatus();
      final parts = <String>[];
      if (status.isReadyToPrint) parts.add('Ready');
      if (status.isPaperOut) parts.add('Paper out');
      if (status.isHeadOpen) parts.add('Head open');
      if (status.isPaused) parts.add('Paused');
      if (status.isHeadTooHot) parts.add('Overheated');
      if (status.isRibbonOut) parts.add('Ribbon out');
      setState(() => _status = 'Status: ${parts.join(', ')}');
    } on PlatformException catch (e) {
      _setError(e);
    }
  }

  Future<void> _printLabel() async {
    setState(() => _status = 'Printing...');
    try {
      // Build a label using flutter_zpl_generator
      final generator = ZplGenerator(
        config: ZplConfiguration(
          printWidth: 4 * 203, // 4 inches at 203 DPI
          labelLength: 3 * 203, // 3 inches at 203 DPI
        ),
        commands: [
          ZplText(text: 'Flutter ZPL Printer', x: 20, y: 20),
          ZplText(text: 'Example Label', x: 20, y: 60),
          ZplBarcode(
            data: '1234567890',
            type: ZplBarcodeType.code128,
            height: 80,
            x: 20,
            y: 120,
          ),
        ],
      );

      final payload = await generator.build();
      await _plugin.printZpl(payload);
      setState(() => _status = 'Printed!');
    } on PlatformException catch (e) {
      _setError(e);
    }
  }

  Future<void> _fetchSettings() async {
    setState(() => _status = 'Fetching settings...');
    try {
      final settings = await _plugin.getSettings();
      setState(() => _status = 'Got ${settings.length} settings');

      if (!mounted) return;
      // Show settings in a dialog
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Printer Settings'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView(
              children: settings.entries
                  .take(50)
                  .map((e) => ListTile(
                        title: Text(e.key, style: const TextStyle(fontSize: 12)),
                        subtitle: Text(e.value),
                        dense: true,
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on PlatformException catch (e) {
      _setError(e);
    }
  }

  void _setError(PlatformException e) {
    if (mounted) {
      setState(() => _status = 'Error [${e.code}]: ${e.message}');
    }
  }

  @override
  void dispose() {
    _foundSub?.cancel();
    _completedSub?.cancel();
    _plugin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ZPL Printer Example')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Status: $_status', textAlign: TextAlign.center),
          ),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: _startDiscovery,
                child: const Text('Discover'),
              ),
              if (_isConnected) ...[
                ElevatedButton(
                  onPressed: _checkStatus,
                  child: const Text('Status'),
                ),
                ElevatedButton(
                  onPressed: _printLabel,
                  child: const Text('Print'),
                ),
                ElevatedButton(
                  onPressed: _fetchSettings,
                  child: const Text('Settings'),
                ),
                ElevatedButton(
                  onPressed: _disconnect,
                  child: const Text('Disconnect'),
                ),
              ],
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (_, i) {
                final d = _devices[i];
                final isConnected = d.address == _connectedDevice?.address;
                return ListTile(
                  title: Text(d.name),
                  subtitle: Text('${d.address} (${d.type.name})'),
                  trailing: isConnected
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: isConnected ? null : () => _connect(d),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

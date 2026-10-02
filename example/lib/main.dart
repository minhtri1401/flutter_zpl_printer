import 'package:flutter/material.dart';

import 'src/ble_tab.dart';
import 'src/usb_tab.dart';
import 'src/wifi_tab.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_zpl_printer example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

/// One tab per transport. Each tab discovers printers its own way and opens
/// a [PrinterPage] once connected.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Zebra printer demo'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.bluetooth), text: 'Bluetooth'),
              Tab(icon: Icon(Icons.wifi), text: 'Wi-Fi'),
              Tab(icon: Icon(Icons.usb), text: 'USB'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [BleTab(), WifiTab(), UsbTab()],
        ),
      ),
    );
  }
}

# flutter_zpl_printer example

A small app that shows the three transports side by side:

| Tab | What it does |
| :--- | :--- |
| **Bluetooth** | Scans for Zebra printers over Bluetooth LE (`BleDiscovery.discoverZebra`). Requests runtime permissions on Android. |
| **Wi-Fi** | Finds printers with UDP broadcast and multicast (`DiscoveryService.discoverAll`), or connects to a typed IP on port 9100 (`TcpConnection.zpl`). |
| **USB** | Lists attached printers (`UsbDiscovery.enumerate`) and refreshes on plug/unplug (`UsbHotplugStream.events`). macOS, Windows, and Android only. **Experimental:** not yet confirmed working on any platform. |

Tap a printer to open the printer screen:

- live status (`getStatus`): ready, head open, paper out, ribbon out, paused
- printer info (`getMetadata`): model, name, serial, firmware, battery, IP
- print editable ZPL (`printZpl`)
- print a configuration label (`printConfigurationLabel`) and calibrate media (`calibrate`)
- read any SGD setting (`getSetting`)
- print a test picture with `printImage` and with `printLabel(ZplGenerator(...))` (both use the included
  `flutter_zpl_generator`, the hardware-tested path), plus the lower-level `GraphicsUtil.printImage` (`^GF`)
  uncompressed and with Z64 (not yet verified on a printer)

Source layout:

```
lib/main.dart             app shell with the three tabs
lib/src/ble_tab.dart      Bluetooth LE discovery + permissions
lib/src/wifi_tab.dart     network discovery + manual IP
lib/src/usb_tab.dart      USB enumeration + hot-plug
lib/src/printer_page.dart connected printer screen
lib/src/common.dart       connect helper, error messages, shared widgets
lib/src/test_image.dart   draws the test picture used by "Print image"
```

Run it:

```bash
cd example
flutter run -d macos    # or windows, or an iOS/Android device
```

USB is experimental in this release (untested on macOS and Android, failing on Windows). See "Known issues" in the package README.

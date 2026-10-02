# flutter_zpl_printer example

A small app that shows the three transports side by side:

| Tab | What it does |
| :--- | :--- |
| **Bluetooth** | Scans for Zebra printers over Bluetooth LE (`BleDiscovery.discoverZebra`). Requests runtime permissions on Android. |
| **Wi-Fi** | Finds printers with UDP broadcast and multicast (`DiscoveryService.discoverAll`), or connects to a typed IP on port 9100 (`TcpConnection.zpl`). |
| **USB** | Lists attached printers (`UsbDiscovery.enumerate`) and refreshes on plug/unplug (`UsbHotplugStream.events`). macOS, Windows, and Android only. |

Tap a printer to open the printer screen:

- live status (`getStatus`): ready, head open, paper out, ribbon out, paused
- printer info (`getMetadata`): model, name, serial, firmware, battery, IP
- print editable ZPL (`printZpl`)
- print a configuration label (`printConfigurationLabel`) and calibrate media (`calibrate`)
- read any SGD setting (`getSetting`)

Source layout:

```
lib/main.dart             app shell with the three tabs
lib/src/ble_tab.dart      Bluetooth LE discovery + permissions
lib/src/wifi_tab.dart     network discovery + manual IP
lib/src/usb_tab.dart      USB enumeration + hot-plug
lib/src/printer_page.dart connected printer screen
lib/src/common.dart       connect helper, error messages, shared widgets
```

Run it:

```bash
cd example
flutter run -d macos    # or windows, or an iOS/Android device
```

USB on Windows has a known issue in this release. See "Known issues" in the package README.

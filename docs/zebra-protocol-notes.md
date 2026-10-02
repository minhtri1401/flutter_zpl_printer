# Zebra Printer Protocol Notes

Background research on how Zebra printers exchange data with a host (connection channels, command encoding, status polling, graphics), gathered while studying the behavior of Zebra's Android SDK (`com.zebra.sdk.comm` and `com.zebra.sdk.printer`). These notes served as the foundation for this multi-platform Flutter library (Android, iOS, macOS, Windows, Linux).

## 1. Connection Interfaces & Transports
Zebra abstracts all hardware data transfer behind the `ConnectionA` and `Connection` interfaces (resembling standard I/O streams).

### Bluetooth (Classic/BTLE)
- **Protocol:** Uses standard RFCOMM/SPP (Serial Port Profile) sockets over Bluetooth (`android.bluetooth.BluetoothSocket`).
- **UUIDs:** The SDK enforces specific UUIDs to discover different service channels.
  - **Printing Channel (SPP):** `00001101-0000-1000-8000-00805F9B34FB`
  - **Status Channel:** `AEB33570-0B7B-11E3-8FFD-0800200C9A66`
- **Implementation Note for Flutter:** You can use the `flutter_blue_plus` or similar plugins. When connecting, look exclusively for these UUIDs to send data buffers.

### TCP / Wi-Fi
- **Protocol:** Raw TCP sockets (`java.net.Socket`).
- **Ports:** 
  - Default **ZPL Port:** `9100` (Raw PDL printing)
  - Default **CPCL Port:** `6101`
- **Implementation Note for Flutter:** Use Dart's native `Socket.connect(ip, port)` from `dart:io`.

### USB
- **Protocol:** Uses Native Android `UsbManager` and `UsbDeviceConnection` utilizing USB Bulk Transfer endpoints.
- **Initialization:** Queries the device's metadata using the command `! U1 getvar "device.unique_id"\r\n` immediately after connecting to verify the serial number.
- **Card Printers:** The SDK uses a `MAX_CARD_USB_WRITE_SIZE` limit of `16384` bytes per packet.

## 2. Core Data Transfer Protocol (ZPL Encapsulation)
While users write standard string ZPL (e.g. `^XA...^XZ`), the internal SDK transforms specific characters into internal hex control characters before pushing the byte array to the stream.

According to `com.zebra.sdk.util.internal.ZPLUtilities`:
- **`~` (Tilde / Command Char):** Transformed internally to Byte `16` (`0x10`)
- **`^` (Caret / Format Char):** Transformed internally to Byte `30` (`0x1E`)
- **`,` (Comma / Delimiter):** Transformed internally to Byte `31` (`0x1F`)

**Example Raw Byte Commands sent over Stream:**
- **Status Query:** `[ 16, 72, 83 ]` -> Equivalent to `~HS` (Host Status)
- **Calibrate:** `[ 16, 74, 67 ]` -> Equivalent to `~JC`
- **Restore Defaults:** `[ 30, 88, 65, 30, 74, 85, 70, 30, 88, 90 ]` -> `^XA^JUF^XZ`

*Note: For the Flutter library, unless sending proprietary encoded internal commands, you can just send raw standard ZPL strings encoded as UTF-8 arrays, but knowing the control character mappings helps debug responses.*

## 3. Two-Way Communication & State Polling

### Language Discovery
When a printer connects, the SDK automatically determines if it's ZPL, CPCL, or Line Print by querying the firmware.
- **SGD Method (Set/Get Do):** Sends `! U1 getvar "device.languages"\r\n`
- **JSON Method (Link-OS):** Sends `{}{\"device.languages\":null}`

### Reading Printer Storage & Drive Info
Files stored on the printer's E:, R: (RAM), or Z: drives are queried using either XML or JSON channels.
- **Command Used:** `{}{\"file.drive_listing\":\"E:\"}`
- **Parser Expectation:** The printer responds with a JSON array mapping file names to memory sizing, CRC32 checks, and access flags (`READ ONLY`, `RAM`, `ONBOARD FLASH`).

### Read Timeouts and Streaming
- **Chunked Writes:** Buffers larger than 1024 bytes are sliced (`MAX_DATA_TO_WRITE_TO_STREAM_AT_ONCE = 1024`), sent over the output stream, flushed, and delayed briefly (`Sleeper.sleep(10)`).
- **Socket Reads:** Handled asynchronously via `bytesAvailable()`. Standard read timeout is `5000ms`, and wait-for-data polling intervals are `500ms`.

## 4. Graphics & Image Handling
Images are not sent raw; they are manipulated via `GraphicsUtilZpl`.
- **Dithering:** Images are converted to monochrome 1-bit raster maps (dithering).
- **Compression:** The buffer is run through Run-Length Encoding (RLE).
- **Payload:** Constructed using the `^GFA` (Graphic Field - ASCII) ZPL command:
  ```zpl
  ^FO<x>,<y>^GFA,<total_bytes>,<total_bytes>,<bytes_per_row>,[...RLE Encoded Image Data...]
  ```
- **Firmware Uploads / Storing Images:** Performed using the `~DY` (Download Graphics) command rather than `^GF`.

## Takeaways for `flutter_zpl_printer`

1. **Decouple Connectors:** Create abstract `PrinterConnection` classes (e.g. `BluetoothConnection`, `TcpConnection`) that implement `write(Uint8List)` and `read()`. This exactly mimics `ConnectionA.java`.
2. **Implement SGD (Set/Get Do):** Allow users to send `! U1 ...` strings because that is the backbone of fetching statuses and printer configuration data (like `device.unique_id` or `file.drive_info`).
3. **Chunking algorithm:** When sending large ZPL strings or graphics, apply the *1024-byte chunking + 10ms sleep delay* approach used in Java to prevent hardware buffer overflows on older Zebra models.
4. **Bluetooth UUID enforcement:** Hardcode the printing channel `00001101-0000-1000-8000-00805F9B34FB` directly into your multi-platform BLE implementation to skip characteristic discovery logic where possible.

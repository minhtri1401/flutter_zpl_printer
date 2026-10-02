# Developer & Contributor Guide

Welcome to the `flutter_zpl_printer` development team! This guide is designed to onboard human developers quickly, explaining how to set up your environment, understand the architecture, and contribute to the library.

If you are an AI assistant or Agent, please refer to the `llms.txt` root file instead.

---

## 1. Local Environment Setup

This project uses Flutter and specifically relies on **`fvm` (Flutter Version Manager)** to ensure consistent tooling across all developers.

### Prerequisites
- Install [FVM](https://fvm.app/docs/getting_started/installation)
- (Optional but recommended) Install `melos` if you plan to manage multiple packages in the future.

### Initialization
```bash
# Clone the repo
git clone https://github.com/your-repo/flutter_zpl_printer_all.git
cd flutter_zpl_printer_all

# Install dependencies using FVM
fvm flutter pub get
```

---

## 2. Testing & Quality Control

We do **not** run tests against physical Zebra printers in CI/CD. All tests use a simulated connection layer.

### Running Tests
```bash
# Run the entire test suite
fvm flutter test

# Run a specific module
fvm flutter test test/connection/tcp_connection_test.dart
```

### The `MockConnection` Pattern
Before writing business logic, understand `MockConnection` located at `test/mocks/mock_connection.dart`. 
Whenever you write a new feature, you must inject `MockConnection` to trap the output payload (the bytes your code tried to send) and feed it dummy responses (the simulated printer response).

```dart
test('My new command works', () async {
  final conn = MockConnection();
  conn.queueResponse(Uint8List.fromList(utf8.encode('"OK"'))); // Mock the printer
  
  final result = await MyNewUtil.sendCommand(conn);
  
  expect(result, equals('OK'));
  expect(conn.lastWritten, contains('my_command')); // Verify we sent the right thing
});
```

---

## 3. Core Architectural Concepts

To keep `flutter_zpl_printer` clean and scalable, we do not bundle everything into one giant `ZebraPrinter` class. We use a layered architecture.

### The Connection Layer (`lib/src/connection/`)
Every action in the SDK takes a `Connection` as its base. 
- You should NEVER hard-code a TCP Socket or BLE characteristic inside your command utilities. 
- You simply call `await connection.write(data)` or `await connection.sendAndWaitForValidResponse(...)`.

### The Static Utility Pattern (`lib/src/printer/`)
Because Zebra printers have hundreds of commands (Settings, Files, Formatting, Firmware, Alerting), we split them into static classes.
* `Sgd` -> Handles `! U1` commands.
* `FormatUtil` -> Handles ZPL templates (`~DF`, `^XF`).
* `FileUtil` -> Handles Drive Operations (`E:`, `R:`).

### The ZebraPrinter Facade
The actual `ZebraPrinter` class merely wraps these static utilities for the end-user so they have a nice API. It delegates the work down.

---

## 4. How to Add a New Feature or Command

Let's say you want to add a feature to change the printer's LCD backlight setting.

**Step 1: Write the Utility Logic**
Find the appropriate utility class (e.g., `Sgd`). If it fits perfectly there, use it!
```dart
// (In your app or contributing to lib/src/printer/sgd.dart)
Future<void> setBacklight(Connection connection, bool isOn) async {
  final value = isOn ? 'on' : 'off';
  await Sgd.set('display.backlight', value, connection);
}
```

**Step 2: Add it to the Facade**
Expose it cleanly to the end user in `ZebraPrinter`:
```dart
class ZebraPrinter {
  // ...
  Future<void> setBacklight(bool isOn) async {
    await Sgd.set('display.backlight', isOn ? 'on' : 'off', connection);
  }
}
```

**Step 3: Write a Test**
Map out the mock behavior to ensure you didn't break anything.

---

## 5. Golden Rules for Developers

1. **Never use timeouts as standard waiting logic.** 
   When waiting for a response, do not just `await Future.delayed(3 seconds)`. Printers can be wildly slow or wildly fast. You must use `ResponseValidators` (e.g., `ResponseValidators.sgd()`) to parse the byte stream dynamically until it's complete.
   
2. **Handle Chunky Data.**
   If you are creating images or firmware uploads, ensure you rely on the Connection's built-in chunking logic (512 bytes). Emitting a 3MB string to a TCP socket on an older ZT230 printer will crash its buffer.

3. **No generic Exception catching.**
   Always handle `ConnectionClosedException` or `ConnectionTimeoutException` explicitly. If something fails due to networking, the user should know it was networking, not a generic Dart error.

4. **Lint before you push.**
   ```bash
   fvm flutter analyze
   ```

## 📚 For More Detailed Reading
If you want to read deeper into specific layers, see the original detailed docs:
- [Code Standards](docs/code-standards.md)
- [System Architecture](docs/system-architecture.md)
- [Codebase Summary](docs/codebase-summary.md)

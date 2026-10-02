# Code Standards & Conventions

This document establishes architectural and style guidelines for the `flutter_zpl_printer` codebase.

## File Organization

### Naming Conventions

- **Files:** kebab-case (e.g., `tcp_connection.dart`, `response_validators.dart`)
- **Classes:** PascalCase (e.g., `class TcpConnection {}`)
- **Methods/Functions:** camelCase (e.g., `sendAndWaitForResponse()`)
- **Constants:** camelCase or SCREAMING_SNAKE_CASE (depends on context)
- **Variables:** camelCase

### File Size Guidelines

- Target: **≤200 lines per file** for optimal context management
- Rationale: Improves readability, reduces cognitive load, simplifies testing
- Exception: Auto-generated files or protocol handlers may exceed this

### Directory Structure

```
lib/
├── src/
│   ├── connection/          # Transport layer
│   ├── discovery/           # Printer discovery
│   ├── printer/             # High-level operations
│   ├── graphics/            # Image/GRF handling
│   ├── models/              # Data classes
│   └── exceptions/          # Error types
└── flutter_zpl_printer.dart              # Barrel exports

test/
├── mocks/                   # MockConnection, test doubles
├── connection/              # Connection layer tests
├── discovery/               # Discovery tests
├── printer/                 # Printer operation tests
├── graphics/                # Graphics tests
└── models/                  # Model tests
```

## Architectural Patterns

### 1. Transport Agnosticism

All printer operations take an abstract `Connection` parameter. Never hardcode TCP or BLE logic.

**Good:**
```dart
Future<String> getSetting(String name, Connection connection) async {
  final data = Uint8List.fromList(utf8.encode('! U1 getvar "$name"\r\n'));
  return await connection.sendAndWaitForValidResponse(data, validator: ...);
}
```

**Bad:**
```dart
Future<String> getSetting(String name, String ipAddress) async {
  final socket = await Socket.connect(ipAddress, 9100);
  // ...hardcoded TCP logic
}
```

### 2. Composition Over Inheritance

Wrap connections rather than subclass them. Enables flexible composition.

**Good:**
```dart
final tcp = TcpConnection(address: '192.168.1.100', port: 9100);
final reliable = ReconnectableConnection(tcp);
final multichannel = MultichannelTcpConnection(
  printAddress: '192.168.1.100',
  statusAddress: '192.168.1.100',
);
```

**Bad:**
```dart
class ReliableTcpConnection extends TcpConnection {
  // Violates LSP; can't compose with other wrappers
}
```

### 3. Static Utility Classes

Organize protocol operations as static utility classes (Sgd, FileUtil, FormatUtil, etc.). Benefits:

- Focuses `ZebraPrinter` on API aggregation, not implementation
- Allows independent testing of each protocol
- Mirrors original Link-OS SDK organization
- Avoids artificial object state

**Pattern:**
```dart
class Sgd {
  Sgd._(); // Private constructor; all methods static

  static Future<String> get(String setting, Connection connection) => ...
  static Future<void> set(String setting, String value, Connection connection) => ...
  static Future<String> doCommand(String action, String value, Connection connection) => ...
}
```

**Usage:**
```dart
final value = await Sgd.get('device.friendly_name', connection);
await Sgd.set('device.friendly_name', 'NewName', connection);
```

### 4. ResponseValidator Pattern

Use predicate validators instead of timeouts to detect complete responses. Reduces timeout-related flakiness.

**Good:**
```dart
final response = await connection.sendAndWaitForValidResponse(
  data,
  validator: ResponseValidators.sgd(),
);
```

**Why:** The validator examines accumulated bytes in real-time. No guessing about timeouts.

### 5. Configuration Over Defaults

Use `ConnectionConfig` for tunable parameters; avoid magic numbers.

**Good:**
```dart
final config = ConnectionConfig(
  maxChunkSize: 256,
  interChunkDelayMs: 50,
  maxTimeoutForRead: 3000,
);
final conn = TcpConnection(address: '192.168.1.100', port: 9100, config: config);
```

**Bad:**
```dart
// Hardcoded timeouts
await Future.delayed(Duration(milliseconds: 1000));
```

## Data Types & Encoding

### Binary Data

- Use `Uint8List` for binary data; never `List<int>`
- Rationale: Zero-copy semantics, better performance
- Convert to/from String via `utf8.encode()` / `utf8.decode()`

```dart
final command = '! U1 getvar "device.friendly_name"\r\n';
final bytes = Uint8List.fromList(utf8.encode(command));
await connection.write(bytes);
```

### Null Safety

- All code uses null safety (`dart:null_safety`)
- Use `?` for nullable types; avoid `!` unless provably safe
- Prefer `.then()` or `await` over `!`

```dart
// Good
Future<String?> getLinkOsVersion() async {
  try {
    return await Sgd.get('appl.link_os_version', connection);
  } catch (_) {
    return null;
  }
}

// Bad
Future<String> getLinkOsVersion() async {
  return (await Sgd.get('appl.link_os_version', connection))!;
}
```

### Async/Await

- Prefer `async`/`await` over `.then()` chaining
- Always return `Future<T>`; never omit type annotation

```dart
// Good
Future<void> printZpl(String zpl) async {
  final data = Uint8List.fromList(utf8.encode(zpl));
  await connection.write(data);
}

// Bad
void printZpl(String zpl) {
  // Missing async; doesn't return Future
}
```

## Error Handling

### Custom Exceptions

Use typed exceptions for specific failure modes.

**Defined Exception Types:**
- `ConnectionException` — Base connection error
- `ConnectionClosedException` — Connection was closed
- `ConnectionTimeoutException` — Operation timed out
- `ReconnectSuccessException` — Reconnect succeeded; retry the command

**Usage:**
```dart
try {
  await connection.open();
} on ConnectionClosedException {
  print('Printer disconnected; attempting reconnect');
} on ConnectionTimeoutException {
  print('Operation timed out');
} on ConnectionException catch (e) {
  print('Connection error: $e');
}
```

### Error Propagation

- Don't swallow exceptions silently
- Wrap lower-level exceptions with context
- Use `Future.catchError()` sparingly; prefer try/catch

```dart
// Good
try {
  return await FileUtil.getFile(connection, path);
} catch (e) {
  throw ConnectionException('Failed to download $path: $e');
}

// Bad
try {
  return await FileUtil.getFile(connection, path);
} catch (_) {
  return null; // Silent failure
}
```

## Validation & Security

### ZPL Injection Prevention

Use `ZplSanitizer` to validate user input before embedding in ZPL.

```dart
// Good
ZplSanitizer.validateFieldData(userInput);
final zpl = '^XA^FO10,10^FD$userInput^FS^XZ';

// Bad
final zpl = '^XA^FO10,10^FD$userInput^FS^XZ'; // Unsanitized
```

### Input Validation

Always validate connection state and input parameters.

```dart
// Good
if (!connection.isConnected) {
  throw ConnectionClosedException('Connection is not open');
}

// Bad
await connection.write(data); // No check; may throw cryptic socket error
```

## SGD Protocol Conventions

### Command Format

- **GET:** `! U1 getvar "$setting"\r\n`
- **SET:** `! U1 setvar "$setting" "$value"\r\n`
- **DO:** `! U1 do "$action" "$value"\r\n`

All responses are quoted; strip quotes automatically.

```dart
// Sgd.get() returns unquoted value
final friendly = await Sgd.get('device.friendly_name', connection);
print(friendly); // "Printer-Lab" (no quotes)
```

### Response Validation

SGD responses may include:
- Quoted values: `"value"`
- Printer prompt: `100,9100>` or similar
- Multiple lines: Some settings return multi-line JSON

Use appropriate `ResponseValidator`:

```dart
// For SGD getvar/do responses
validator: ResponseValidators.sgd()

// For multi-line settings (e.g., network config)
validator: ResponseValidators.multiline(3)

// For JSON responses
validator: ResponseValidators.json()
```

## Testing Patterns

### MockConnection Usage

All unit tests use `MockConnection` from `test/mocks/mock_connection.dart`.

```dart
import 'package:flutter_zpl_printer/src/connection/connection.dart';
import '../mocks/mock_connection.dart';

test('Sgd.get() sends correct command', () async {
  final conn = MockConnection();
  conn.queueResponse(Uint8List.fromList(utf8.encode('"Printer-Lab"')));

  final result = await Sgd.get('device.friendly_name', conn);

  expect(result, equals('Printer-Lab'));
  expect(conn.lastWritten, contains('getvar'));
});
```

### Disconnect Simulation

Test reconnect logic with `simulateDisconnect()`.

```dart
test('ReconnectableConnection retries on disconnect', () async {
  final base = MockConnection();
  base.simulateDisconnect();
  base.queueResponse(Uint8List.fromList(utf8.encode('"OK"')));

  final reliable = ReconnectableConnection(base);
  expect(
    () => reliable.sendAndWaitForResponse(cmd),
    throwsA(isA<ReconnectSuccessException>()),
  );
});
```

### Progress Callback Testing

Test progress callbacks with mutable state.

```dart
test('ProfileUtil reports progress', () async {
  final conn = MockConnection();
  final progress = <String>[];

  await ProfileUtil.createProfile(
    conn,
    onProgress: (status) => progress.add(status),
  );

  expect(progress, contains('Fetching settings...'));
  expect(progress, contains('Creating ZIP...'));
});
```

## Performance Guidelines

### Timeouts

- Default initial timeout: **5000ms** (time to first byte)
- Default read timeout: **1000ms** per poll (time between bytes)
- Outer deadline: **15s** max for entire operation (init + 10x read attempts)

Rationale: Slow printers and networks need breathing room; 15s is empirically safe.

### Chunking

- Default chunk size: **512 bytes**
- Inter-chunk delay: **0ms** (configurable for slow transports)

Rationale: Most printers buffer at least 1KB; 512 is safe and fast.

### Polling

- Poll interval for `bytesAvailable()`: **50ms** (matches SDK)
- Prevents CPU spinning; human-imperceptible latency

## Code Quality Standards

### Linting

- Run `fvm flutter analyze` before commit
- Address all errors; ignore pedantic warnings only with comments
- No `// ignore: lint_rule` without justification

```dart
// Good: Justification for ignore
// ignore: avoid_empty_else
if (condition) {
  // do something
} else {
  // nothing to do
}

// Bad: No explanation
// ignore: avoid_empty_else
```

### Documentation

- **Public API:** JSDoc-style comments with examples
- **Complex logic:** Explain the "why", not the "what"
- **Workarounds:** Link to issue or reference SDK behavior

```dart
/// Query printer status via ~HS command.
///
/// Returns structured [PrinterStatus] with media, temperature, and error info.
/// Blocks until response is received (default 5s timeout).
///
/// Throws [ConnectionClosedException] if printer is offline.
///
/// Example:
/// ```dart
/// final status = await PrinterStatus.query(connection);
/// print(status.mediaStatus); // 'ready' or 'out_of_media'
/// ```
Future<PrinterStatus> static query(Connection connection) async {
  // ...
}
```

### Comments

Use comments sparingly; code should be self-documenting.

```dart
// Good: Explains a non-obvious workaround
// SDK's SGD response includes surrounding quotes; strip them
return result.substring(1, result.length - 1);

// Bad: Obvious comment
// Increment the counter
count++;
```

## Dart Conventions

### Imports

- Organize imports: `dart:` → `package:` → relative
- Use `show` to narrow imports in tests

```dart
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'connection.dart';
import '../exceptions/connection_exception.dart';
```

### Formatting

- Use 2-space indentation (Dart standard)
- Run `dart format` before commit
- Line length: 80–100 chars (wrapped if longer)

### Final & Const

- Use `final` for variables that aren't reassigned
- Use `const` for compile-time constants
- Use `late` sparingly; prefer late initialization in constructors

```dart
// Good
final config = ConnectionConfig(maxChunkSize: 512);
const defaultTimeout = 5000;

// Bad
var config = ConnectionConfig(maxChunkSize: 512);
```

## Version & Dependency Management

### Dart SDK

- **Minimum:** Dart 3.10.0
- **Target:** Latest stable

### Dependencies

- **universal_ble:** ^1.2.0 (BLE transport)
- **image:** ^4.8.0 (PNG/JPEG decoding)
- **archive:** ^4.0.0 (ZIP handling)

All are stable, well-maintained libraries. Avoid experimental packages.

### Breaking Changes

- Never change `Connection` interface signatures without major version bump
- New optional parameters are fine (non-breaking)
- Deprecate before removing; wait one major version

```dart
// Good: New optional parameter
Future<Uint8List> sendAndWaitForValidResponse(
  Uint8List data, {
  int? initialTimeout,
  int? readTimeout,
  required ResponseValidator validator,
  Duration? outerDeadline, // New; optional; safe
}) async { ... }

// Requires major bump; document in changelog
// Bad: Removed parameter
Future<Uint8List> sendAndWaitForValidResponse(
  Uint8List data, {
  required ResponseValidator validator,
}) async { ... }
```

## YAGNI / KISS / DRY Principles

### YAGNI (You Aren't Gonna Need It)

Don't implement "future-proofing" features without concrete use cases.

- No abstract factory patterns without multiple implementations
- No "pluggable" loggers until we actually have multiple log backends
- Focus on what the spec requires now

### KISS (Keep It Simple, Stupid)

Prefer straightforward solutions over clever ones.

```dart
// Good: Simple, obvious
final bytes = buffer.takeBytes();

// Avoid: Too clever
final bytes = buffer.length > 0 ? buffer.takeBytes() : Uint8List(0);
```

### DRY (Don't Repeat Yourself)

Extract common logic into utilities or base classes.

```dart
// Good: Shared timeout logic
Future<T> _withTimeout<T>(
  Duration timeout,
  Future<T> Function() operation,
) async {
  return operation().timeout(timeout);
}

// Bad: Repeated timeout wrapping in each method
Future<String> get(...) async {
  return Sgd.get(...).timeout(Duration(milliseconds: 5000));
}
```

## Code Review Checklist

Before submitting a PR:

- [ ] All tests pass (`fvm flutter test`)
- [ ] No linting errors (`fvm flutter analyze`)
- [ ] Code is formatted (`dart format .`)
- [ ] Commit message is clear and uses conventional format
- [ ] No hardcoded timeouts, IP addresses, or magic numbers
- [ ] All `Connection` methods are `async`
- [ ] All `Future` return types are annotated
- [ ] Exceptions are typed (not generic `Exception`)
- [ ] New public API has JSDoc comments
- [ ] Tests use `MockConnection` (no real hardware)
- [ ] No `// ignore:` without justification
- [ ] File size is ≤200 lines (unless exceptional)
- [ ] No secrets committed (API keys, credentials, etc.)

## References

- **Flutter Style Guide:** https://dart.dev/guides/language/effective-dart
- **Dart Null Safety:** https://dart.dev/null-safety
- **Link-OS SDK:** `libs/ZSDK_src/` (protocol reference)

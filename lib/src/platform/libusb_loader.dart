import 'dart:ffi';
import 'dart:io';

import '../exceptions/connection_exception.dart';

/// Hand-rolled thin wrapper around libusb-1.0. Exposes only the functions
/// [UsbPlatformFfi] actually calls; regenerate manually by mirroring signatures
/// from `libusb_bindings.g.dart` if more are needed.
///
/// Loads the platform-appropriate shared library and surfaces a
/// [UsbLibLoadException] when it can't be found or lacks the expected symbols.
class LibusbBindings {
  final DynamicLibrary _lib;

  // Function typedefs (Dart side).
  late final int Function(Pointer<Pointer<Void>>) init;
  late final void Function(Pointer<Void>) exit;
  late final int Function(Pointer<Void>, int, Pointer<Pointer<Void>>) wrapSysDevice;
  late final int Function(Pointer<Void>, Pointer<Pointer<Pointer<Void>>>) getDeviceList;
  late final void Function(Pointer<Pointer<Void>>, int) freeDeviceList;
  late final int Function(Pointer<Void>, Pointer<LibusbDeviceDescriptor>) getDeviceDescriptor;
  late final int Function(Pointer<Void>, Pointer<Pointer<Void>>) open;
  late final void Function(Pointer<Void>) close;
  late final int Function(Pointer<Void>, int) claimInterface;
  late final int Function(Pointer<Void>, int) releaseInterface;
  late final int Function(Pointer<Void>, int, Pointer<Uint8>, int, Pointer<Int32>, int)
      bulkTransfer;
  late final int Function(Pointer<Void>, int) clearHalt;
  late final int Function(Pointer<Void>) resetDevice;
  late final int Function(Pointer<Void>, int, int, Pointer<Uint8>, int) getStringDescriptorAscii;
  late final int Function(Pointer<Void>, int) setAutoDetachKernelDriver;

  LibusbBindings._(this._lib) {
    init = _lib
        .lookup<NativeFunction<Int32 Function(Pointer<Pointer<Void>>)>>('libusb_init')
        .asFunction();
    exit = _lib
        .lookup<NativeFunction<Void Function(Pointer<Void>)>>('libusb_exit')
        .asFunction();
    wrapSysDevice = _lib
        .lookup<
            NativeFunction<
                Int32 Function(Pointer<Void>, IntPtr,
                    Pointer<Pointer<Void>>)>>('libusb_wrap_sys_device')
        .asFunction();
    getDeviceList = _lib
        .lookup<
            NativeFunction<
                IntPtr Function(Pointer<Void>,
                    Pointer<Pointer<Pointer<Void>>>)>>('libusb_get_device_list')
        .asFunction();
    freeDeviceList = _lib
        .lookup<
            NativeFunction<
                Void Function(
                    Pointer<Pointer<Void>>, Int32)>>('libusb_free_device_list')
        .asFunction();
    getDeviceDescriptor = _lib
        .lookup<
            NativeFunction<
                Int32 Function(Pointer<Void>,
                    Pointer<LibusbDeviceDescriptor>)>>('libusb_get_device_descriptor')
        .asFunction();
    open = _lib
        .lookup<
            NativeFunction<
                Int32 Function(Pointer<Void>,
                    Pointer<Pointer<Void>>)>>('libusb_open')
        .asFunction();
    close = _lib
        .lookup<NativeFunction<Void Function(Pointer<Void>)>>('libusb_close')
        .asFunction();
    claimInterface = _lib
        .lookup<
            NativeFunction<
                Int32 Function(Pointer<Void>, Int32)>>('libusb_claim_interface')
        .asFunction();
    releaseInterface = _lib
        .lookup<
            NativeFunction<
                Int32 Function(Pointer<Void>, Int32)>>('libusb_release_interface')
        .asFunction();
    bulkTransfer = _lib
        .lookup<
            NativeFunction<
                Int32 Function(Pointer<Void>, UnsignedChar, Pointer<Uint8>, Int32,
                    Pointer<Int32>, UnsignedInt)>>('libusb_bulk_transfer')
        .asFunction();
    clearHalt = _lib
        .lookup<
            NativeFunction<
                Int32 Function(Pointer<Void>, UnsignedChar)>>('libusb_clear_halt')
        .asFunction();
    resetDevice = _lib
        .lookup<NativeFunction<Int32 Function(Pointer<Void>)>>('libusb_reset_device')
        .asFunction();
    getStringDescriptorAscii = _lib
        .lookup<
            NativeFunction<
                Int32 Function(Pointer<Void>, Uint8, UnsignedShort, Pointer<Uint8>,
                    Int32)>>('libusb_get_string_descriptor_ascii')
        .asFunction();
    setAutoDetachKernelDriver = _lib
        .lookup<
            NativeFunction<
                Int32 Function(Pointer<Void>,
                    Int32)>>('libusb_set_auto_detach_kernel_driver')
        .asFunction();
  }

  /// Loads libusb for the current platform. Throws [UsbLibLoadException] on
  /// failure. Cache the result — the underlying library is process-singleton.
  static LibusbBindings load() {
    if (_cached != null) return _cached!;
    try {
      DynamicLibrary lib;
      if (Platform.isMacOS) {
        // Frameworks/ bundle lookup, then system.
        lib = _tryOpen([
          'libusb-1.0.dylib',
          '@loader_path/../Frameworks/libusb-1.0.dylib',
          '/opt/homebrew/lib/libusb-1.0.dylib',
          '/usr/local/lib/libusb-1.0.dylib',
        ]);
      } else if (Platform.isLinux) {
        lib = _tryOpen(['libusb-1.0.so.0', 'libusb-1.0.so']);
      } else if (Platform.isWindows) {
        lib = _tryOpen(['libusb-1.0.dll']);
      } else if (Platform.isAndroid) {
        lib = _tryOpen(['libusb-1.0.so']);
      } else {
        throw UsbUnsupportedOnPlatformException();
      }
      _cached = LibusbBindings._(lib);
      return _cached!;
    } on UsbConnectionException {
      rethrow;
    } catch (e) {
      throw UsbLibLoadException('Failed to load libusb: $e');
    }
  }

  static DynamicLibrary _tryOpen(List<String> candidates) {
    Object? lastError;
    for (final c in candidates) {
      try {
        return DynamicLibrary.open(c);
      } catch (e) {
        lastError = e;
      }
    }
    throw UsbLibLoadException('Could not load libusb from: $candidates ($lastError)');
  }

  static LibusbBindings? _cached;
}

/// Minimal subset of `libusb_device_descriptor` — only the fields UsbPlatformFfi
/// reads. Layout MUST match the C struct bit-for-bit.
final class LibusbDeviceDescriptor extends Struct {
  @Uint8()
  external int bLength;
  @Uint8()
  external int bDescriptorType;
  @Uint16()
  external int bcdUSB;
  @Uint8()
  external int bDeviceClass;
  @Uint8()
  external int bDeviceSubClass;
  @Uint8()
  external int bDeviceProtocol;
  @Uint8()
  external int bMaxPacketSize0;
  @Uint16()
  external int idVendor;
  @Uint16()
  external int idProduct;
  @Uint16()
  external int bcdDevice;
  @Uint8()
  external int iManufacturer;
  @Uint8()
  external int iProduct;
  @Uint8()
  external int iSerialNumber;
  @Uint8()
  external int bNumConfigurations;
}

/// Public alias for the descriptor struct, used by [UsbPlatformFfi].
typedef DeviceDescriptorStruct = LibusbDeviceDescriptor;

extension LibusbBindingsReadSerialExt on LibusbBindings {
  // Convenience name preserved across refactors.
  int getStringDescriptorAsciiHelper(
          Pointer<Void> handle, int index, int langid, Pointer<Uint8> buf, int len) =>
      getStringDescriptorAscii(handle, index, langid, buf, len);
}

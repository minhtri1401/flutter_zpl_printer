// USB HostApi implementation.
// - macOS: full IOKit-based implementation.
// - iOS:   stub that throws USB_UNSUPPORTED on every call.

#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
  import Foundation
  import IOKit
  import IOKit.usb
#endif

final class UsbHostApiImpl: UsbHostApi {

#if os(macOS)
  func isSupported() throws -> Bool { true }

  func enumerate(filter: UsbEnumerateFilter,
                 completion: @escaping (Result<[UsbDeviceRecord], Error>) -> Void) {
    let records = IOKitUsbEnumerator.enumerate(
      vendorId: filter.vendorId.flatMap { Int($0) },
      includeDescriptorStrings: filter.includeDescriptorStrings
    )
    completion(.success(records))
  }

  func hasPermission(path: String) throws -> Bool {
    // macOS permission is per-app (entitlement / sandbox), not per-device.
    // If we could enumerate the device we have permission.
    return true
  }

  func requestPermission(path: String,
                         completion: @escaping (Result<Bool, Error>) -> Void) {
    // No dialog to show — treat as granted.
    completion(.success(true))
  }

  func openForFfi(path: String,
                  completion: @escaping (Result<UsbOpenResult, Error>) -> Void) {
    guard let rec = IOKitUsbEnumerator.enumerate(vendorId: nil, includeDescriptorStrings: true)
      .first(where: { $0.path == path }) else {
      completion(.failure(PigeonError(
        code: "USB_DEVICE_DISAPPEARED",
        message: "Device \(path) disappeared",
        details: nil
      )))
      return
    }
    guard let iface = rec.interfaceNumber,
          let epIn = rec.bulkInEndpoint,
          let epOut = rec.bulkOutEndpoint,
          let maxOut = rec.wMaxPacketSizeOut else {
      completion(.failure(PigeonError(
        code: "USB_INTERFACE_NOT_FOUND",
        message: "Printer-class interface not found at \(path)",
        details: nil
      )))
      return
    }
    // macOS path: Dart FFI opens via libusb by matching VID+PID+serial —
    // platformHandle stays 0.
    let result = UsbOpenResult(
      platformHandle: 0,
      vendorId: rec.vendorId,
      productId: rec.productId,
      serialNumber: rec.serialNumber,
      claimedInterfaceNumber: iface,
      bulkInEndpoint: epIn,
      bulkOutEndpoint: epOut,
      wMaxPacketSizeOut: maxOut
    )
    completion(.success(result))
  }

  func closeAfterFfi(path: String,
                     completion: @escaping (Result<Void, Error>) -> Void) {
    // macOS: no retained native state; Dart FFI fully owns the handle.
    completion(.success(()))
  }
#else
  // iOS stub — every method surfaces USB_UNSUPPORTED.
  func isSupported() throws -> Bool { false }

  func enumerate(filter: UsbEnumerateFilter,
                 completion: @escaping (Result<[UsbDeviceRecord], Error>) -> Void) {
    completion(.success([]))
  }

  func hasPermission(path: String) throws -> Bool { false }

  func requestPermission(path: String,
                         completion: @escaping (Result<Bool, Error>) -> Void) {
    completion(.failure(PigeonError(
      code: "USB_UNSUPPORTED",
      message: "USB is not supported on iOS",
      details: nil
    )))
  }

  func openForFfi(path: String,
                  completion: @escaping (Result<UsbOpenResult, Error>) -> Void) {
    completion(.failure(PigeonError(
      code: "USB_UNSUPPORTED",
      message: "USB is not supported on iOS",
      details: nil
    )))
  }

  func closeAfterFfi(path: String,
                     completion: @escaping (Result<Void, Error>) -> Void) {
    completion(.success(()))
  }
#endif
}

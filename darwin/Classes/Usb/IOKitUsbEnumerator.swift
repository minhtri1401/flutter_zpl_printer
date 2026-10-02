// IOKit-based USB enumeration for macOS.
// Walks IOUSBDevice objects, extracts VID/PID/serial + printer-class interface.

#if os(macOS)
import Foundation
import IOKit
import IOKit.usb

enum IOKitUsbEnumerator {

  static func enumerate(vendorId: Int?, includeDescriptorStrings: Bool) -> [UsbDeviceRecord] {
    guard let matching = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary? else {
      return []
    }
    if let vid = vendorId {
      matching[kUSBVendorID] = vid
    }

    var iter: io_iterator_t = 0
    let port: mach_port_t
    if #available(macOS 12.0, *) {
      port = kIOMainPortDefault
    } else {
      port = kIOMasterPortDefault
    }
    let kr = IOServiceGetMatchingServices(port, matching.copy() as! CFDictionary, &iter)
    guard kr == kIOReturnSuccess else { return [] }
    defer { IOObjectRelease(iter) }

    var records: [UsbDeviceRecord] = []
    var service: io_service_t = IOIteratorNext(iter)
    while service != 0 {
      defer { IOObjectRelease(service); service = IOIteratorNext(iter) }

      let vid = readInt(service, kUSBVendorID)
      let pid = readInt(service, kUSBProductID)
      guard vid != nil, pid != nil else { continue }

      // IOKit registry path as the opaque identifier.
      var pathBuffer = [CChar](repeating: 0, count: 1024)
      let pathRc = IORegistryEntryGetPath(service, kIOServicePlane, &pathBuffer)
      let path = pathRc == KERN_SUCCESS ? String(cString: pathBuffer) : "io-service/\(service)"

      let manufacturer = includeDescriptorStrings
        ? readString(service, "USB Vendor Name") : nil
      let product = includeDescriptorStrings
        ? readString(service, "USB Product Name") : nil
      let serial = includeDescriptorStrings
        ? readString(service, "USB Serial Number") : nil

      // For the printer-class interface + endpoints we'd normally open the
      // device and iterate interfaces. That's expensive and requires opening
      // the device plugin interface — we skip it here and let Dart FFI
      // rediscover via libusb when it opens. The Dart side falls back to
      // the libusb-reported endpoint addresses.
      records.append(UsbDeviceRecord(
        vendorId: Int64(vid!),
        productId: Int64(pid!),
        path: path,
        hasPermission: true,
        manufacturer: manufacturer,
        product: product,
        serialNumber: serial,
        interfaceNumber: 0,        // Placeholder — real value discovered by libusb post-open.
        bulkInEndpoint: 0x81,      // Zebra printers: typical bulk-IN. Overridden by libusb.
        bulkOutEndpoint: 0x01,     // Zebra printers: typical bulk-OUT. Overridden by libusb.
        wMaxPacketSizeOut: 64,     // Conservative default; libusb corrects post-open.
        driverBinding: nil
      ))
    }
    return records
  }

  private static func readInt(_ service: io_service_t, _ key: String) -> Int? {
    guard let property = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
      .takeRetainedValue() else { return nil }
    return (property as? NSNumber)?.intValue
  }

  private static func readString(_ service: io_service_t, _ key: String) -> String? {
    guard let property = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
      .takeRetainedValue() else { return nil }
    return property as? String
  }
}
#endif

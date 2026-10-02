// Hand-rolled USB hot-plug EventChannel handler.
//
// macOS: uses IOKit's IOServiceAddMatchingNotification with kIOFirstMatch and
// kIOTerminated to deliver attach/detach notifications on the main runloop.
// iOS:   no-op; onListen never emits.

#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
  import Foundation
  import IOKit
  import IOKit.usb
#endif

final class UsbHotplugStreamHandler: NSObject, FlutterStreamHandler {

#if os(macOS)
  private var sink: FlutterEventSink?
  private var notifyPort: IONotificationPortRef?
  private var addedIter: io_iterator_t = 0
  private var removedIter: io_iterator_t = 0

  func onListen(withArguments arguments: Any?,
                eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    let iokitPort: mach_port_t
    if #available(macOS 12.0, *) {
      iokitPort = kIOMainPortDefault
    } else {
      iokitPort = kIOMasterPortDefault
    }
    let port = IONotificationPortCreate(iokitPort)
    self.notifyPort = port
    if let src = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() {
      CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
    }

    // Attach: kIOFirstMatchNotification fires for every new IOUSBDevice.
    let matching = IOServiceMatching(kIOUSBDeviceClassName)
    let selfPtr = Unmanaged.passUnretained(self).toOpaque()

    var attachIter: io_iterator_t = 0
    IOServiceAddMatchingNotification(
      port,
      kIOFirstMatchNotification,
      matching,
      { (context, iterator) in
        let handler = Unmanaged<UsbHotplugStreamHandler>.fromOpaque(context!).takeUnretainedValue()
        handler.handleEvent(type: "attached", iterator: iterator)
      },
      selfPtr,
      &attachIter
    )
    addedIter = attachIter
    // Drain initial iterator — required by IOKit docs even if we don't want to
    // treat already-attached devices as "just attached" right now. We skip
    // emitting during drain.
    drainIterator(attachIter, emit: false)

    var detachIter: io_iterator_t = 0
    IOServiceAddMatchingNotification(
      port,
      kIOTerminatedNotification,
      matching,
      { (context, iterator) in
        let handler = Unmanaged<UsbHotplugStreamHandler>.fromOpaque(context!).takeUnretainedValue()
        handler.handleEvent(type: "detached", iterator: iterator)
      },
      selfPtr,
      &detachIter
    )
    removedIter = detachIter
    drainIterator(detachIter, emit: false)

    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    if addedIter != 0 { IOObjectRelease(addedIter); addedIter = 0 }
    if removedIter != 0 { IOObjectRelease(removedIter); removedIter = 0 }
    if let port = notifyPort {
      IONotificationPortDestroy(port)
      notifyPort = nil
    }
    return nil
  }

  private func handleEvent(type: String, iterator: io_iterator_t) {
    drainIterator(iterator, emit: true, type: type)
  }

  private func drainIterator(_ iter: io_iterator_t, emit: Bool, type: String = "") {
    var service = IOIteratorNext(iter)
    while service != 0 {
      defer { IOObjectRelease(service); service = IOIteratorNext(iter) }
      if !emit { continue }
      guard let sink = sink else { continue }

      let vid = readInt(service, kUSBVendorID) ?? 0
      let pid = readInt(service, kUSBProductID) ?? 0
      let serial = readString(service, "USB Serial Number")

      var pathBuffer = [CChar](repeating: 0, count: 1024)
      let pathRc = IORegistryEntryGetPath(service, kIOServicePlane, &pathBuffer)
      let path = pathRc == KERN_SUCCESS ? String(cString: pathBuffer) : "io-service/\(service)"

      DispatchQueue.main.async {
        sink([
          "type": type,
          "vendorId": Int64(vid),
          "productId": Int64(pid),
          "serialNumber": serial,
          "path": path,
          "timestamp_ms": Int64(Date().timeIntervalSince1970 * 1000),
        ])
      }
    }
  }

  private func readInt(_ service: io_service_t, _ key: String) -> Int? {
    guard let p = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
      .takeRetainedValue() else { return nil }
    return (p as? NSNumber)?.intValue
  }

  private func readString(_ service: io_service_t, _ key: String) -> String? {
    guard let p = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
      .takeRetainedValue() else { return nil }
    return p as? String
  }
#else
  func onListen(withArguments arguments: Any?,
                eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    // iOS: no hot-plug; never emits.
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? { return nil }
#endif
}

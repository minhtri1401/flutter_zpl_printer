// Detects the kernel driver bound to a USB device on Windows.
//
// Needed because libusb cannot open a device that's bound to the printer-class
// driver (`usbprint`). The host API surfaces USB_DRIVER_BOUND_TO_SPOOLER with
// a remediation hint when the binding isn't WinUSB.

#ifndef FLUTTER_ZPL_PRINTER_USB_DRIVER_DETECTOR_H_
#define FLUTTER_ZPL_PRINTER_USB_DRIVER_DETECTOR_H_

#include <string>

namespace flutter_zpl_printer {

enum class DriverBinding {
  kWinUsb,
  kUsbPrint,
  kOther,
};

// Normalize a Windows service name (case-insensitive) to one of the
// DriverBinding values. Pure function — easy to test.
DriverBinding ClassifyDriverService(const std::string& service_name);

// Convert the enum to the wire string used in UsbDeviceRecord.driverBinding
// and in log messages.
std::string DriverBindingToString(DriverBinding b);

}  // namespace flutter_zpl_printer

#endif  // FLUTTER_ZPL_PRINTER_USB_DRIVER_DETECTOR_H_

// USB device-path parser for Windows (format:
//   "\\?\USB#VID_0A5F&PID_0027#XXSERIAL#{guid}").
//
// Exposed as a free function so it's trivially testable via GoogleTest.

#ifndef FLUTTER_ZPL_PRINTER_USB_USB_PATH_PARSER_H_
#define FLUTTER_ZPL_PRINTER_USB_USB_PATH_PARSER_H_

#include <optional>
#include <string>

namespace flutter_zpl_printer {

struct ParsedUsbPath {
  int vendor_id = 0;
  int product_id = 0;
  std::optional<std::string> serial;
};

// Parses VID/PID (and optional serial) out of the given Windows USB device
// interface path. Returns `nullopt` if the path isn't a USB interface path.
std::optional<ParsedUsbPath> ParseUsbPath(const std::string& path);

}  // namespace flutter_zpl_printer

#endif  // FLUTTER_ZPL_PRINTER_USB_USB_PATH_PARSER_H_

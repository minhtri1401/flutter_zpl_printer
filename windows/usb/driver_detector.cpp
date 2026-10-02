#include "driver_detector.h"

#include <algorithm>

namespace flutter_zpl_printer {

namespace {
std::string Lower(const std::string& s) {
  std::string out(s.size(), 0);
  std::transform(s.begin(), s.end(), out.begin(),
                 [](unsigned char c) { return static_cast<char>(::tolower(c)); });
  return out;
}
}  // namespace

DriverBinding ClassifyDriverService(const std::string& service_name) {
  const auto s = Lower(service_name);
  if (s == "winusb") return DriverBinding::kWinUsb;
  if (s == "usbprint") return DriverBinding::kUsbPrint;
  return DriverBinding::kOther;
}

std::string DriverBindingToString(DriverBinding b) {
  switch (b) {
    case DriverBinding::kWinUsb: return "WINUSB";
    case DriverBinding::kUsbPrint: return "USBPRINT";
    case DriverBinding::kOther: return "OTHER";
  }
  return "OTHER";
}

}  // namespace flutter_zpl_printer

#include "usb_path_parser.h"

#include <algorithm>
#include <cctype>
#include <cstdlib>

namespace flutter_zpl_printer {

namespace {

int HexToInt(const std::string& hex) {
  return static_cast<int>(std::strtol(hex.c_str(), nullptr, 16));
}

bool MatchesPrefix(const std::string& s, size_t pos, const std::string& prefix) {
  if (pos + prefix.size() > s.size()) return false;
  for (size_t i = 0; i < prefix.size(); ++i) {
    if (std::toupper(static_cast<unsigned char>(s[pos + i])) !=
        std::toupper(static_cast<unsigned char>(prefix[i]))) {
      return false;
    }
  }
  return true;
}

}  // namespace

std::optional<ParsedUsbPath> ParseUsbPath(const std::string& path) {
  // Uppercase copy for easier matching; preserve the original for serial extraction.
  const auto npos = std::string::npos;
  const auto usb_pos = path.find("USB#");
  if (usb_pos == npos) return std::nullopt;

  size_t cursor = usb_pos + 4;  // skip "USB#"
  if (!MatchesPrefix(path, cursor, "VID_")) return std::nullopt;
  cursor += 4;
  if (cursor + 4 > path.size()) return std::nullopt;
  int vid = HexToInt(path.substr(cursor, 4));
  cursor += 4;

  // Expect "&PID_" or "&MI_" etc. — we need &PID_ specifically.
  const auto pid_pos = path.find("PID_", cursor);
  if (pid_pos == npos) return std::nullopt;
  cursor = pid_pos + 4;
  if (cursor + 4 > path.size()) return std::nullopt;
  int pid = HexToInt(path.substr(cursor, 4));
  cursor += 4;

  ParsedUsbPath out;
  out.vendor_id = vid;
  out.product_id = pid;

  // Optional serial. Next '#' separates from the device-instance id, which
  // typically contains the serial if the device reports iSerialNumber.
  const auto serial_hash = path.find('#', cursor);
  if (serial_hash != npos) {
    const auto serial_end = path.find('#', serial_hash + 1);
    const auto serial = (serial_end == npos)
        ? path.substr(serial_hash + 1)
        : path.substr(serial_hash + 1, serial_end - serial_hash - 1);
    // Skip empty serials and those that look like GUIDs ("{...}").
    if (!serial.empty() && serial.front() != '{') {
      out.serial = serial;
    }
  }
  return out;
}

}  // namespace flutter_zpl_printer

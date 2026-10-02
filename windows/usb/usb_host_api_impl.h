#ifndef FLUTTER_ZPL_PRINTER_USB_USB_HOST_API_IMPL_H_
#define FLUTTER_ZPL_PRINTER_USB_USB_HOST_API_IMPL_H_

#include "usb_messages.g.h"

namespace flutter_zpl_printer {

class UsbHostApiImpl : public UsbHostApi {
 public:
  UsbHostApiImpl() = default;
  ~UsbHostApiImpl() override = default;

  ErrorOr<bool> IsSupported() override;

  void Enumerate(
      const UsbEnumerateFilter& filter,
      std::function<void(ErrorOr<flutter::EncodableList> reply)> result) override;

  ErrorOr<bool> HasPermission(const std::string& path) override;

  void RequestPermission(
      const std::string& path,
      std::function<void(ErrorOr<bool> reply)> result) override;

  void OpenForFfi(
      const std::string& path,
      std::function<void(ErrorOr<UsbOpenResult> reply)> result) override;

  void CloseAfterFfi(
      const std::string& path,
      std::function<void(std::optional<FlutterError> reply)> result) override;
};

}  // namespace flutter_zpl_printer

#endif  // FLUTTER_ZPL_PRINTER_USB_USB_HOST_API_IMPL_H_

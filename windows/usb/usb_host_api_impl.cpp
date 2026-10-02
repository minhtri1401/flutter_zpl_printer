#include "usb_host_api_impl.h"

#include <windows.h>
#include <setupapi.h>
#include <initguid.h>
#include <usbiodef.h>
#include <cfgmgr32.h>

#include <algorithm>
#include <cctype>
#include <string>
#include <vector>

#include "driver_detector.h"
#include "usb_path_parser.h"

#pragma comment(lib, "setupapi.lib")
#pragma comment(lib, "cfgmgr32.lib")

namespace flutter_zpl_printer {

namespace {

std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) return {};
  const int size = ::WideCharToMultiByte(CP_UTF8, 0, wide.data(),
                                          static_cast<int>(wide.size()),
                                          nullptr, 0, nullptr, nullptr);
  std::string out(static_cast<size_t>(size), 0);
  ::WideCharToMultiByte(CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()),
                        out.data(), size, nullptr, nullptr);
  return out;
}

std::string ReadDeviceRegistryString(HDEVINFO info, SP_DEVINFO_DATA& data, DWORD property) {
  DWORD size = 0;
  ::SetupDiGetDeviceRegistryPropertyW(info, &data, property, nullptr, nullptr, 0, &size);
  if (size == 0) return {};
  std::wstring buf(size / sizeof(wchar_t), 0);
  if (!::SetupDiGetDeviceRegistryPropertyW(info, &data, property, nullptr,
                                            reinterpret_cast<PBYTE>(buf.data()),
                                            size, nullptr)) {
    return {};
  }
  while (!buf.empty() && buf.back() == 0) buf.pop_back();
  return WideToUtf8(buf);
}

std::vector<UsbDeviceRecord> EnumerateDevices(const UsbEnumerateFilter& filter) {
  std::vector<UsbDeviceRecord> out;
  HDEVINFO info = ::SetupDiGetClassDevsW(&GUID_DEVINTERFACE_USB_DEVICE, nullptr,
                                          nullptr,
                                          DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
  if (info == INVALID_HANDLE_VALUE) return out;

  SP_DEVICE_INTERFACE_DATA iface = {};
  iface.cbSize = sizeof(iface);
  for (DWORD idx = 0;
       ::SetupDiEnumDeviceInterfaces(info, nullptr, &GUID_DEVINTERFACE_USB_DEVICE,
                                      idx, &iface);
       ++idx) {
    DWORD required = 0;
    ::SetupDiGetDeviceInterfaceDetailW(info, &iface, nullptr, 0, &required, nullptr);
    if (required == 0) continue;

    std::vector<BYTE> buffer(required);
    auto* detail = reinterpret_cast<PSP_DEVICE_INTERFACE_DETAIL_DATA_W>(buffer.data());
    detail->cbSize = sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA_W);

    SP_DEVINFO_DATA devinfo = {};
    devinfo.cbSize = sizeof(devinfo);
    if (!::SetupDiGetDeviceInterfaceDetailW(info, &iface, detail, required,
                                             nullptr, &devinfo)) {
      continue;
    }

    const std::string path = WideToUtf8(detail->DevicePath);
    const auto parsed = ParseUsbPath(path);
    if (!parsed.has_value()) continue;
    if (filter.vendor_id() && *filter.vendor_id() != parsed->vendor_id) continue;

    const std::string service = ReadDeviceRegistryString(info, devinfo, SPDRP_SERVICE);
    const DriverBinding binding = ClassifyDriverService(service);

    std::optional<std::string> manufacturer;
    std::optional<std::string> product;
    std::optional<std::string> serial = parsed->serial;

    if (filter.include_descriptor_strings()) {
      const std::string mfg = ReadDeviceRegistryString(info, devinfo, SPDRP_MFG);
      const std::string friendly = ReadDeviceRegistryString(info, devinfo, SPDRP_FRIENDLYNAME);
      if (!mfg.empty()) manufacturer = mfg;
      if (!friendly.empty()) product = friendly;
    }

    out.emplace_back(UsbDeviceRecord(
        parsed->vendor_id, parsed->product_id, path, /*has_permission=*/true));
    UsbDeviceRecord& rec = out.back();
    if (manufacturer) rec.set_manufacturer(*manufacturer);
    if (product) rec.set_product(*product);
    if (serial) rec.set_serial_number(*serial);
    rec.set_driver_binding(DriverBindingToString(binding));
    // Interface / endpoints are discovered by libusb post-open on Windows.
    rec.set_interface_number(0);
    rec.set_bulk_in_endpoint(0x81);
    rec.set_bulk_out_endpoint(0x01);
    rec.set_w_max_packet_size_out(64);
  }

  ::SetupDiDestroyDeviceInfoList(info);
  return out;
}

}  // namespace

ErrorOr<bool> UsbHostApiImpl::IsSupported() { return true; }

void UsbHostApiImpl::Enumerate(
    const UsbEnumerateFilter& filter,
    std::function<void(ErrorOr<flutter::EncodableList> reply)> result) {
  try {
    const auto records = EnumerateDevices(filter);
    flutter::EncodableList out;
    out.reserve(records.size());
    for (const auto& r : records) {
      out.emplace_back(flutter::CustomEncodableValue(r));
    }
    result(ErrorOr<flutter::EncodableList>(std::move(out)));
  } catch (const std::exception& e) {
    result(ErrorOr<flutter::EncodableList>(FlutterError("USB_UNKNOWN", e.what())));
  }
}

ErrorOr<bool> UsbHostApiImpl::HasPermission(const std::string& /*path*/) {
  return true;  // Windows has no per-device permission gate.
}

void UsbHostApiImpl::RequestPermission(
    const std::string& /*path*/,
    std::function<void(ErrorOr<bool> reply)> result) {
  result(ErrorOr<bool>(true));
}

void UsbHostApiImpl::OpenForFfi(
    const std::string& path,
    std::function<void(ErrorOr<UsbOpenResult> reply)> result) {
  const auto parsed = ParseUsbPath(path);
  if (!parsed.has_value()) {
    result(ErrorOr<UsbOpenResult>(FlutterError(
        "USB_DEVICE_NOT_FOUND", "Not a USB device path: " + path)));
    return;
  }

  // Check the driver binding. If usbprint (ZDesigner / print-class), surface
  // a remediation-friendly error so the UI can explain the fix.
  HDEVINFO info = ::SetupDiGetClassDevsW(&GUID_DEVINTERFACE_USB_DEVICE, nullptr,
                                          nullptr,
                                          DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
  std::string service;
  if (info != INVALID_HANDLE_VALUE) {
    SP_DEVICE_INTERFACE_DATA iface = {};
    iface.cbSize = sizeof(iface);
    for (DWORD idx = 0;
         ::SetupDiEnumDeviceInterfaces(info, nullptr, &GUID_DEVINTERFACE_USB_DEVICE,
                                        idx, &iface);
         ++idx) {
      DWORD required = 0;
      ::SetupDiGetDeviceInterfaceDetailW(info, &iface, nullptr, 0, &required, nullptr);
      if (required == 0) continue;
      std::vector<BYTE> buffer(required);
      auto* detail = reinterpret_cast<PSP_DEVICE_INTERFACE_DETAIL_DATA_W>(buffer.data());
      detail->cbSize = sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA_W);
      SP_DEVINFO_DATA devinfo = {};
      devinfo.cbSize = sizeof(devinfo);
      if (!::SetupDiGetDeviceInterfaceDetailW(info, &iface, detail, required,
                                               nullptr, &devinfo)) continue;
      if (WideToUtf8(detail->DevicePath) != path) continue;
      service = ReadDeviceRegistryString(info, devinfo, SPDRP_SERVICE);
      break;
    }
    ::SetupDiDestroyDeviceInfoList(info);
  }

  const DriverBinding binding = ClassifyDriverService(service);
  if (binding == DriverBinding::kUsbPrint) {
    result(ErrorOr<UsbOpenResult>(FlutterError(
        "USB_DRIVER_BOUND_TO_SPOOLER",
        "Device is bound to the Windows print spooler driver (usbprint). "
        "Rebind to WinUSB via Zadig to use direct USB access.")));
    return;
  }

  UsbOpenResult out(
      /*platform_handle=*/0,
      /*vendor_id=*/static_cast<int64_t>(parsed->vendor_id),
      /*product_id=*/static_cast<int64_t>(parsed->product_id),
      /*claimed_interface_number=*/0,
      /*bulk_in_endpoint=*/0x81,
      /*bulk_out_endpoint=*/0x01,
      /*w_max_packet_size_out=*/64);
  if (parsed->serial) out.set_serial_number(*parsed->serial);
  result(ErrorOr<UsbOpenResult>(std::move(out)));
}

void UsbHostApiImpl::CloseAfterFfi(
    const std::string& /*path*/,
    std::function<void(std::optional<FlutterError> reply)> result) {
  result(std::nullopt);
}

}  // namespace flutter_zpl_printer

#ifndef FLUTTER_PLUGIN_FLUTTER_ZPL_PRINTER_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_ZPL_PRINTER_PLUGIN_H_

#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_zpl_printer {

class UsbHostApiImpl;

class FlutterZplPrinterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterZplPrinterPlugin();

  virtual ~FlutterZplPrinterPlugin();

  // Disallow copy and assign.
  FlutterZplPrinterPlugin(const FlutterZplPrinterPlugin&) = delete;
  FlutterZplPrinterPlugin& operator=(const FlutterZplPrinterPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // USB host API instance (kept alive as long as the plugin is registered).
  std::unique_ptr<UsbHostApiImpl> usb_host_api_;

  // Hot-plug EventChannel (Pigeon doesn't generate C++ EventChannel — hand-rolled).
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> hotplug_channel_;
};

}  // namespace flutter_zpl_printer

#endif  // FLUTTER_PLUGIN_FLUTTER_ZPL_PRINTER_PLUGIN_H_

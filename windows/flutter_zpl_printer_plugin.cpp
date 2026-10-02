#include "flutter_zpl_printer_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

#include "usb/usb_host_api_impl.h"
#include "usb/usb_hotplug_stream_handler.h"
#include "usb/usb_messages.g.h"

namespace flutter_zpl_printer {

// static
void FlutterZplPrinterPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter_zpl_printer",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterZplPrinterPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  // USB HostApi (Pigeon-generated).
  auto host_api = std::make_unique<UsbHostApiImpl>();
  UsbHostApi::SetUp(registrar->messenger(), host_api.get());
  plugin->usb_host_api_ = std::move(host_api);

  // USB hot-plug EventChannel (hand-rolled; stub until v0.3 WM_DEVICECHANGE work).
  auto hotplug_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "com.zebra.flutter_zpl_printer/usb/hotplug",
          &flutter::StandardMethodCodec::GetInstance());
  auto hotplug_handler = std::make_unique<UsbHotplugStreamHandler>();
  hotplug_channel->SetStreamHandler(std::move(hotplug_handler));
  plugin->hotplug_channel_ = std::move(hotplug_channel);

  registrar->AddPlugin(std::move(plugin));
}

FlutterZplPrinterPlugin::FlutterZplPrinterPlugin() {}

FlutterZplPrinterPlugin::~FlutterZplPrinterPlugin() {}

void FlutterZplPrinterPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getPlatformVersion") == 0) {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
  } else {
    result->NotImplemented();
  }
}

}  // namespace flutter_zpl_printer

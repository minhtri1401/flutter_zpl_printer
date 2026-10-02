#ifndef FLUTTER_ZPL_PRINTER_USB_USB_HOTPLUG_STREAM_HANDLER_H_
#define FLUTTER_ZPL_PRINTER_USB_USB_HOTPLUG_STREAM_HANDLER_H_

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler.h>
#include <flutter/encodable_value.h>

#include <memory>

namespace flutter_zpl_printer {

// Minimal hot-plug EventChannel handler. Full WM_DEVICECHANGE wiring lives
// in a v0.3 follow-up — for v1 we register the handler so the channel is
// reachable from Dart, but emit no events. Dart consumers must rely on
// explicit re-enumeration until the full implementation lands.
class UsbHotplugStreamHandler
    : public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  UsbHotplugStreamHandler() = default;
  ~UsbHotplugStreamHandler() override = default;

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListenInternal(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override;

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancelInternal(
      const flutter::EncodableValue* arguments) override;

 private:
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;
};

}  // namespace flutter_zpl_printer

#endif  // FLUTTER_ZPL_PRINTER_USB_USB_HOTPLUG_STREAM_HANDLER_H_

#include "usb_hotplug_stream_handler.h"

namespace flutter_zpl_printer {

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
UsbHotplugStreamHandler::OnListenInternal(
    const flutter::EncodableValue* /*arguments*/,
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
  sink_ = std::move(events);
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
UsbHotplugStreamHandler::OnCancelInternal(
    const flutter::EncodableValue* /*arguments*/) {
  sink_.reset();
  return nullptr;
}

}  // namespace flutter_zpl_printer

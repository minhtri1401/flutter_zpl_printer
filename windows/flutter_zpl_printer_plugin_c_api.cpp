#include "include/flutter_zpl_printer/flutter_zpl_printer_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_zpl_printer_plugin.h"

void FlutterZplPrinterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_zpl_printer::FlutterZplPrinterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

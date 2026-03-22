package com.example.flutter_zpl_printer

import io.flutter.embedding.engine.plugins.FlutterPlugin

class FlutterZplPrinterPlugin : FlutterPlugin {

    private var hostApiImpl: PrinterHostApiImpl? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val flutterApi = PrinterFlutterApi(binding.binaryMessenger)
        hostApiImpl = PrinterHostApiImpl(flutterApi)
        PrinterHostApi.setUp(binding.binaryMessenger, hostApiImpl)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        PrinterHostApi.setUp(binding.binaryMessenger, null)
        hostApiImpl?.tearDown()
        hostApiImpl = null
    }
}

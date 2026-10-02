package com.example.flutter_zpl_printer

import android.content.Context
import com.example.flutter_zpl_printer.usb.UsbHostApiImpl
import com.example.flutter_zpl_printer.usb.UsbHotplugStreamHandler
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** FlutterZplPrinterPlugin */
class FlutterZplPrinterPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var hotplugChannel: EventChannel? = null
    private var hotplugHandler: UsbHotplugStreamHandler? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val ctx = flutterPluginBinding.applicationContext

        // Legacy method channel used by existing (non-USB) calls.
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_zpl_printer")
        channel.setMethodCallHandler(this)

        // USB HostApi (Pigeon) + hotplug EventChannel.
        UsbHostApi.setUp(
            flutterPluginBinding.binaryMessenger,
            UsbHostApiImpl(ctx),
        )
        val streamHandler = UsbHotplugStreamHandler(ctx)
        val eventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "com.zebra.flutter_zpl_printer/usb/hotplug",
        )
        eventChannel.setStreamHandler(streamHandler)
        hotplugChannel = eventChannel
        hotplugHandler = streamHandler
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result,
    ) {
        if (call.method == "getPlatformVersion") {
            result.success("Android ${android.os.Build.VERSION.RELEASE}")
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        hotplugChannel?.setStreamHandler(null)
        hotplugHandler?.onCancel(null)
        hotplugChannel = null
        hotplugHandler = null
        UsbHostApi.setUp(binding.binaryMessenger, null)
    }
}

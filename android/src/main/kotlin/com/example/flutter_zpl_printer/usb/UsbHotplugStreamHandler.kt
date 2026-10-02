package com.example.flutter_zpl_printer.usb

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import io.flutter.plugin.common.EventChannel

/**
 * Hand-rolled USB hot-plug EventChannel (`com.zebra.flutter_zpl_printer/usb/hotplug`).
 *
 * Uniform wire payload across Android / macOS / Windows — defined in
 * USB transport spec §3.3. Native side emits `Map<String, Any?>` encoded
 * with [io.flutter.plugin.common.StandardMessageCodec].
 */
class UsbHotplugStreamHandler(private val context: Context) : EventChannel.StreamHandler {
    private var sink: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                } ?: return
                val type = when (intent.action) {
                    UsbManager.ACTION_USB_DEVICE_ATTACHED -> "attached"
                    UsbManager.ACTION_USB_DEVICE_DETACHED -> "detached"
                    else -> return
                }
                sink?.success(
                    mapOf(
                        "type" to type,
                        "vendorId" to device.vendorId.toLong(),
                        "productId" to device.productId.toLong(),
                        "serialNumber" to runCatching { device.serialNumber }.getOrNull(),
                        "path" to device.deviceName,
                        "timestamp_ms" to System.currentTimeMillis(),
                    ),
                )
            }
        }
        val filter = IntentFilter().apply {
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
        this.receiver = receiver
    }

    override fun onCancel(arguments: Any?) {
        receiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
                // Already unregistered; fine.
            }
        }
        receiver = null
        sink = null
    }
}

package com.example.flutter_zpl_printer.usb

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import com.example.flutter_zpl_printer.FlutterError
import com.example.flutter_zpl_printer.UsbDeviceRecord
import com.example.flutter_zpl_printer.UsbEnumerateFilter
import com.example.flutter_zpl_printer.UsbHostApi
import com.example.flutter_zpl_printer.UsbOpenResult

/**
 * Android implementation of the USB host API.
 *
 * Uses `UsbManager` for enumeration/open/permission. Holds `UsbDeviceConnection`
 * instances across [openForFfi]/[closeAfterFfi] so the file descriptor passed
 * to Dart FFI remains valid until the caller explicitly closes.
 */
class UsbHostApiImpl(
    private val context: Context,
    private val permissionHandler: UsbPermissionHandler = UsbPermissionHandler(context),
) : UsbHostApi {
    private val usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private val openConnections = mutableMapOf<String, UsbDeviceConnection>()

    override fun isSupported(): Boolean = true

    override fun enumerate(
        filter: UsbEnumerateFilter,
        callback: (Result<List<UsbDeviceRecord>>) -> Unit,
    ) {
        try {
            val vid = filter.vendorId?.toInt()
            val records = usbManager.deviceList.values
                .filter { vid == null || it.vendorId == vid }
                .map { device -> device.toRecord(usbManager, filter.includeDescriptorStrings) }
            callback(Result.success(records))
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("USB_UNKNOWN", t.message, null)))
        }
    }

    override fun hasPermission(path: String): Boolean {
        val device = findDevice(path) ?: return false
        return usbManager.hasPermission(device)
    }

    override fun requestPermission(
        path: String,
        callback: (Result<Boolean>) -> Unit,
    ) {
        val device = findDevice(path)
        if (device == null) {
            callback(Result.failure(FlutterError("USB_DEVICE_NOT_FOUND", "Device $path not attached", null)))
            return
        }
        if (usbManager.hasPermission(device)) {
            callback(Result.success(true))
            return
        }
        permissionHandler.request(device) { granted ->
            callback(Result.success(granted))
        }
    }

    override fun openForFfi(
        path: String,
        callback: (Result<UsbOpenResult>) -> Unit,
    ) {
        try {
            val device = findDevice(path)
                ?: throw FlutterError("USB_DEVICE_DISAPPEARED", "Device $path disappeared", null)
            if (!usbManager.hasPermission(device)) {
                throw FlutterError("USB_PERMISSION_DENIED", "No USB permission for $path", null)
            }
            val connection = usbManager.openDevice(device)
                ?: throw FlutterError("USB_DEVICE_BUSY", "Device $path is busy or inaccessible", null)

            val iface = device.findPrinterInterface()
                ?: run {
                    connection.close()
                    throw FlutterError("USB_INTERFACE_NOT_FOUND", "No printer-class interface on $path", null)
                }
            if (!connection.claimInterface(iface, /* force */ true)) {
                connection.close()
                throw FlutterError("USB_DEVICE_BUSY", "Failed to claim printer interface", null)
            }
            val endpoints = iface.findBulkEndpoints()
            if (endpoints.bulkIn == null || endpoints.bulkOut == null) {
                connection.releaseInterface(iface)
                connection.close()
                throw FlutterError("USB_INTERFACE_NOT_FOUND", "Bulk endpoints not found", null)
            }

            openConnections[path] = connection

            val result = UsbOpenResult(
                platformHandle = connection.fileDescriptor.toLong(),
                vendorId = device.vendorId.toLong(),
                productId = device.productId.toLong(),
                serialNumber = runCatching { device.serialNumber }.getOrNull(),
                claimedInterfaceNumber = iface.id.toLong(),
                bulkInEndpoint = endpoints.bulkIn.address.toLong(),
                bulkOutEndpoint = endpoints.bulkOut.address.toLong(),
                wMaxPacketSizeOut = endpoints.bulkOut.maxPacketSize.toLong(),
            )
            callback(Result.success(result))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("USB_UNKNOWN", t.message ?: t.javaClass.simpleName, null)))
        }
    }

    override fun closeAfterFfi(
        path: String,
        callback: (Result<Unit>) -> Unit,
    ) {
        val connection = openConnections.remove(path)
        try {
            connection?.close()
            callback(Result.success(Unit))
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("USB_UNKNOWN", t.message, null)))
        }
    }

    private fun findDevice(path: String): UsbDevice? = usbManager.deviceList[path]
}

private data class BulkEndpoints(val bulkIn: UsbEndpoint?, val bulkOut: UsbEndpoint?)

private fun UsbDevice.findPrinterInterface(): UsbInterface? {
    for (i in 0 until interfaceCount) {
        val iface = getInterface(i)
        if (iface.interfaceClass == UsbConstants.USB_CLASS_PRINTER) {
            return iface
        }
    }
    return null
}

private fun UsbInterface.findBulkEndpoints(): BulkEndpoints {
    var bulkIn: UsbEndpoint? = null
    var bulkOut: UsbEndpoint? = null
    for (i in 0 until endpointCount) {
        val ep = getEndpoint(i)
        if (ep.type != UsbConstants.USB_ENDPOINT_XFER_BULK) continue
        when (ep.direction) {
            UsbConstants.USB_DIR_IN -> if (bulkIn == null) bulkIn = ep
            UsbConstants.USB_DIR_OUT -> if (bulkOut == null) bulkOut = ep
        }
    }
    return BulkEndpoints(bulkIn, bulkOut)
}

private fun UsbDevice.toRecord(
    usbManager: UsbManager,
    includeDescriptorStrings: Boolean,
): UsbDeviceRecord {
    val iface = findPrinterInterface()
    val endpoints = iface?.findBulkEndpoints()
    return UsbDeviceRecord(
        vendorId = vendorId.toLong(),
        productId = productId.toLong(),
        path = deviceName,
        hasPermission = usbManager.hasPermission(this),
        manufacturer = if (includeDescriptorStrings) runCatching { manufacturerName }.getOrNull() else null,
        product = if (includeDescriptorStrings) runCatching { productName }.getOrNull() else null,
        serialNumber = if (includeDescriptorStrings) runCatching { serialNumber }.getOrNull() else null,
        interfaceNumber = iface?.id?.toLong(),
        bulkInEndpoint = endpoints?.bulkIn?.address?.toLong(),
        bulkOutEndpoint = endpoints?.bulkOut?.address?.toLong(),
        wMaxPacketSizeOut = endpoints?.bulkOut?.maxPacketSize?.toLong(),
        driverBinding = null, // Android-irrelevant — only set on Windows.
    )
}

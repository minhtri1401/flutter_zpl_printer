package com.example.flutter_zpl_printer

import android.os.Handler
import android.os.Looper
import com.zebra.sdk.comm.BluetoothConnection
import com.zebra.sdk.comm.Connection
import com.zebra.sdk.comm.TcpConnection
import com.zebra.sdk.printer.ZebraPrinterFactory
import com.zebra.sdk.printer.discovery.BluetoothDiscoverer
import com.zebra.sdk.printer.discovery.DiscoveredPrinter
import com.zebra.sdk.printer.discovery.DiscoveryHandler
import com.zebra.sdk.printer.discovery.NetworkDiscoverer
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/// Error codes matching iOS ZebraErrorCode for cross-platform tracking.
object ZebraErrorCode {
    const val CONNECTION_OPEN_FAILED = 1001
    const val WRITE_FAILED = 2001
    const val PRINTER_INSTANCE_FAILED = 3001
    const val STATUS_QUERY_FAILED = 3002
    const val SETTINGS_NOT_SUPPORTED = 4003
    const val NOT_CONNECTED = 5001
}

class PrinterHostApiImpl(
    private val flutterApi: PrinterFlutterApi,
) : PrinterHostApi {

    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var connection: Connection? = null
    @Volatile private var isDiscovering = false

    // --- Discovery ---

    override fun startDiscovery(callback: (Result<Unit>) -> Unit) {
        isDiscovering = true
        executor.execute {
            try {
                NetworkDiscoverer.findPrinters(object : DiscoveryHandler {
                    override fun foundPrinter(printer: DiscoveredPrinter) {
                        if (!isDiscovering) return
                        val device = PrinterDevice(
                            name = printer.address,
                            address = printer.address,
                            type = ConnectionType.WIFI,
                        )
                        mainHandler.post { flutterApi.onPrinterFound(device) {} }
                    }

                    override fun discoveryFinished() {
                        if (!isDiscovering) {
                            mainHandler.post {
                                flutterApi.onDiscoveryCompleted {}
                                callback(Result.success(Unit))
                            }
                            return
                        }
                        try {
                            BluetoothDiscoverer.findPrinters(null, object : DiscoveryHandler {
                                override fun foundPrinter(printer: DiscoveredPrinter) {
                                    if (!isDiscovering) return
                                    val device = PrinterDevice(
                                        name = printer.address,
                                        address = printer.address,
                                        type = ConnectionType.BLUETOOTH,
                                    )
                                    mainHandler.post { flutterApi.onPrinterFound(device) {} }
                                }

                                override fun discoveryFinished() {
                                    isDiscovering = false
                                    mainHandler.post {
                                        flutterApi.onDiscoveryCompleted {}
                                        callback(Result.success(Unit))
                                    }
                                }

                                override fun discoveryError(message: String?) {
                                    isDiscovering = false
                                    mainHandler.post {
                                        flutterApi.onDiscoveryCompleted {}
                                        callback(Result.success(Unit))
                                    }
                                }
                            })
                        } catch (e: Exception) {
                            isDiscovering = false
                            mainHandler.post {
                                flutterApi.onDiscoveryCompleted {}
                                callback(Result.success(Unit))
                            }
                        }
                    }

                    override fun discoveryError(message: String?) {
                        discoveryFinished()
                    }
                })
            } catch (e: Exception) {
                isDiscovering = false
                mainHandler.post { callback(Result.failure(e)) }
            }
        }
    }

    override fun stopDiscovery() {
        isDiscovering = false
    }

    // --- Connection ---

    override fun connect(address: String, type: ConnectionType, callback: (Result<Unit>) -> Unit) {
        executor.execute {
            try {
                connection?.close()
                connection = when (type) {
                    ConnectionType.BLUETOOTH -> BluetoothConnection(address)
                    ConnectionType.WIFI -> TcpConnection(address, 9100)
                }
                connection!!.open()
                mainHandler.post { callback(Result.success(Unit)) }
            } catch (e: Exception) {
                connection = null
                mainHandler.post { callback(Result.failure(e)) }
            }
        }
    }

    override fun disconnect() {
        executor.execute {
            try {
                connection?.close()
            } catch (_: Exception) {
            } finally {
                connection = null
            }
        }
    }

    // --- Print ---

    override fun printZpl(zplPayload: String, callback: (Result<Unit>) -> Unit) {
        executor.execute {
            try {
                val conn = connection
                    ?: throw FlutterError("${ZebraErrorCode.NOT_CONNECTED}", "Not connected to a printer")
                conn.write(zplPayload.toByteArray(Charsets.UTF_8))
                mainHandler.post { callback(Result.success(Unit)) }
            } catch (e: Exception) {
                mainHandler.post { callback(Result.failure(e)) }
            }
        }
    }

    // --- Status ---

    override fun getStatus(callback: (Result<PrinterStatus>) -> Unit) {
        executor.execute {
            try {
                val conn = connection
                    ?: throw FlutterError("${ZebraErrorCode.NOT_CONNECTED}", "Not connected to a printer")
                val printer = ZebraPrinterFactory.getInstance(conn)
                val s = printer.currentStatus
                val status = PrinterStatus(
                    isReadyToPrint = s.isReadyToPrint,
                    isHeadOpen = s.isHeadOpen,
                    isHeadCold = s.isHeadCold,
                    isHeadTooHot = s.isHeadTooHot,
                    isPaperOut = s.isPaperOut,
                    isRibbonOut = s.isRibbonOut,
                    isReceiveBufferFull = s.isReceiveBufferFull,
                    isPaused = s.isPaused,
                    isPartialFormatInProgress = s.isPartialFormatInProgress,
                    labelLengthInDots = s.labelLengthInDots.toLong(),
                    numberOfFormatsInReceiveBuffer = s.numberOfFormatsInReceiveBuffer.toLong(),
                    labelsRemainingInBatch = s.labelsRemainingInBatch.toLong(),
                )
                mainHandler.post { callback(Result.success(status)) }
            } catch (e: Exception) {
                mainHandler.post { callback(Result.failure(e)) }
            }
        }
    }

    // --- Settings ---

    override fun getSettings(callback: (Result<Map<String?, String?>>) -> Unit) {
        executor.execute {
            try {
                val conn = connection
                    ?: throw FlutterError("${ZebraErrorCode.NOT_CONNECTED}", "Not connected to a printer")
                val printer = ZebraPrinterFactory.getInstance(conn)
                val linkOsPrinter = ZebraPrinterFactory.createLinkOsPrinter(printer)
                    ?: throw FlutterError("${ZebraErrorCode.SETTINGS_NOT_SUPPORTED}", "Printer does not support Link-OS settings")
                val settings: Map<String?, String?> = linkOsPrinter.allSettingValues
                mainHandler.post { callback(Result.success(settings)) }
            } catch (e: Exception) {
                mainHandler.post { callback(Result.failure(e)) }
            }
        }
    }

    // --- Cleanup ---

    fun tearDown() {
        isDiscovering = false
        executor.execute {
            try { connection?.close() } catch (_: Exception) {}
            connection = null
        }
        executor.shutdown()
    }
}

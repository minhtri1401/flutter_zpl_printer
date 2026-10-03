/// Configuration for connection timeouts and chunking behavior.
///
/// Default values match SDK's `ConnectionA` constants.
class ConnectionConfig {
  /// Max timeout for initial read response (ms). SDK default: 5000.
  final int maxTimeoutForRead;

  /// Time to wait for additional data after initial response (ms). SDK default: 500.
  final int timeToWaitForMoreData;

  /// Max bytes per write chunk. SDK default: 1024.
  final int maxChunkSize;

  /// Delay between write chunks (ms). SDK default: 10.
  final int interChunkDelayMs;

  /// Internal read buffer size. SDK default: 16384.
  final int readBufferSize;

  // ─── USB transport ─────────────────────────────────────────────────────

  /// Per-transfer timeout passed to libusb_bulk_transfer. Default: 5000 ms.
  final int usbBulkTimeoutMs;

  /// Chunk size for USB bulk-OUT writes. 0 = auto-detect from the device's
  /// wMaxPacketSize on open. Override when targeting specific firmware.
  final int usbMaxChunkSize;

  /// Number of `clear_halt` retries after LIBUSB_ERROR_PIPE before surfacing
  /// [UsbTransferStalledException]. Default: 2.
  final int usbStallRetries;

  /// Request libusb to detach the kernel driver before claiming the interface.
  /// Linux-relevant; no-op on Android / macOS / Windows. Default: true.
  final bool usbDetachKernelDriver;

  const ConnectionConfig({
    this.maxTimeoutForRead = 5000,
    this.timeToWaitForMoreData = 500,
    this.maxChunkSize = 1024,
    this.interChunkDelayMs = 10,
    this.readBufferSize = 16384,
    this.usbBulkTimeoutMs = 5000,
    this.usbMaxChunkSize = 0,
    this.usbStallRetries = 2,
    this.usbDetachKernelDriver = true,
  });

  ConnectionConfig copyWith({
    int? maxTimeoutForRead,
    int? timeToWaitForMoreData,
    int? maxChunkSize,
    int? interChunkDelayMs,
    int? readBufferSize,
    int? usbBulkTimeoutMs,
    int? usbMaxChunkSize,
    int? usbStallRetries,
    bool? usbDetachKernelDriver,
  }) {
    return ConnectionConfig(
      maxTimeoutForRead: maxTimeoutForRead ?? this.maxTimeoutForRead,
      timeToWaitForMoreData:
          timeToWaitForMoreData ?? this.timeToWaitForMoreData,
      maxChunkSize: maxChunkSize ?? this.maxChunkSize,
      interChunkDelayMs: interChunkDelayMs ?? this.interChunkDelayMs,
      readBufferSize: readBufferSize ?? this.readBufferSize,
      usbBulkTimeoutMs: usbBulkTimeoutMs ?? this.usbBulkTimeoutMs,
      usbMaxChunkSize: usbMaxChunkSize ?? this.usbMaxChunkSize,
      usbStallRetries: usbStallRetries ?? this.usbStallRetries,
      usbDetachKernelDriver:
          usbDetachKernelDriver ?? this.usbDetachKernelDriver,
    );
  }
}

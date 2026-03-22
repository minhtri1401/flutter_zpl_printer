import Foundation
import ExternalAccessory

// Serial queue for all SDK I/O — Zebra SDK is not thread-safe
private let printerQueue = DispatchQueue(label: "com.flutterzplprinter.sdk", qos: .userInitiated)

class PrinterHostApiImpl: NSObject, PrinterHostApi {

    private let flutterApi: PrinterFlutterApi
    /// Opaque connection token returned by ZebraSDKBridge
    private var connection: AnyObject?
    private var isDiscovering = false

    init(flutterApi: PrinterFlutterApi) {
        self.flutterApi = flutterApi
    }

    // MARK: - Discovery

    func startDiscovery(completion: @escaping (Result<Void, Error>) -> Void) {
        guard !isDiscovering else {
            completion(.success(()))
            return
        }
        isDiscovering = true

        printerQueue.async { [weak self] in
            guard let self = self else { return }
            defer { self.isDiscovering = false }

            // Bluetooth MFi — already-paired accessories
            let btDevices = ZebraSDKBridge.connectedBluetoothDevices()
            for info in btDevices {
                guard let name = info["name"], let address = info["address"] else { continue }
                let device = PrinterDevice(name: name, address: address, type: .bluetooth)
                DispatchQueue.main.async {
                    self.flutterApi.onPrinterFound(printer: device) { _ in }
                }
            }

            // Wi-Fi — local broadcast
            var wifiError: NSError?
            let wifiAddresses = ZebraSDKBridge.discoverWifiPrintersWithError(&wifiError)
            for address in wifiAddresses {
                let device = PrinterDevice(name: address, address: address, type: .wifi)
                DispatchQueue.main.async {
                    self.flutterApi.onPrinterFound(printer: device) { _ in }
                }
            }

            DispatchQueue.main.async {
                self.flutterApi.onDiscoveryCompleted { _ in }
            }
            completion(.success(()))
        }
    }

    func stopDiscovery() throws {
        isDiscovering = false
    }

    // MARK: - Connection

    func connect(address: String, type: ConnectionType, completion: @escaping (Result<Void, Error>) -> Void) {
        printerQueue.async { [weak self] in
            guard let self = self else { return }

            if let existing = self.connection {
                ZebraSDKBridge.closeConnection(existing)
                self.connection = nil
            }

            let bridgeType: ZebraConnectionType = type == .bluetooth ? .bluetooth : .wifi

            var connError: NSError?
            if let conn = ZebraSDKBridge.openConnection(toAddress: address,
                                                        type: bridgeType,
                                                        outError: &connError) {
                self.connection = conn as AnyObject
                completion(.success(()))
            } else {
                completion(.failure(connError ?? PrinterError.connectionFailed("Failed to connect to \(address)")))
            }
        }
    }

    func disconnect() throws {
        let conn = connection
        connection = nil
        if let conn = conn {
            printerQueue.async {
                ZebraSDKBridge.closeConnection(conn)
            }
        }
    }

    // MARK: - Print

    func printZpl(zplPayload: String, completion: @escaping (Result<Void, Error>) -> Void) {
        printerQueue.async { [weak self] in
            guard let self = self else { return }
            guard let conn = self.connection else {
                completion(.failure(PrinterError.notConnected))
                return
            }

            var writeError: NSError?
            if ZebraSDKBridge.writeZpl(zplPayload, connection: conn, outError: &writeError) {
                completion(.success(()))
            } else {
                completion(.failure(writeError ?? PrinterError.writeFailed))
            }
        }
    }

    // MARK: - Status

    func getStatus(completion: @escaping (Result<PrinterStatus, Error>) -> Void) {
        printerQueue.async { [weak self] in
            guard let self = self else { return }
            guard let conn = self.connection else {
                completion(.failure(PrinterError.notConnected))
                return
            }
            let result = self.fetchStatus(conn: conn)
            completion(result)
        }
    }

    private func fetchStatus(conn: AnyObject) -> Result<PrinterStatus, Error> {
        var fields = ZebraStatusFields()
        var statusError: NSError?
        let ok = ZebraSDKBridge.getStatusFields(&fields, connection: conn, outError: &statusError)
        guard ok else {
            return .failure(statusError ?? PrinterError.statusFailed("Could not get printer status"))
        }
        // C struct BOOL fields bridge as ObjCBool in Swift; use .boolValue to convert
        let status = PrinterStatus(
            isReadyToPrint: fields.isReadyToPrint.boolValue,
            isHeadOpen: fields.isHeadOpen.boolValue,
            isHeadCold: fields.isHeadCold.boolValue,
            isHeadTooHot: fields.isHeadTooHot.boolValue,
            isPaperOut: fields.isPaperOut.boolValue,
            isRibbonOut: fields.isRibbonOut.boolValue,
            isReceiveBufferFull: fields.isReceiveBufferFull.boolValue,
            isPaused: fields.isPaused.boolValue,
            isPartialFormatInProgress: fields.isPartialFormatInProgress.boolValue,
            labelLengthInDots: Int64(fields.labelLengthInDots),
            numberOfFormatsInReceiveBuffer: Int64(fields.numberOfFormatsInReceiveBuffer),
            labelsRemainingInBatch: Int64(fields.labelsRemainingInBatch)
        )
        return .success(status)
    }

    // MARK: - Settings

    func getSettings(completion: @escaping (Result<[String?: String?], Error>) -> Void) {
        printerQueue.async { [weak self] in
            guard let self = self else { return }
            guard let conn = self.connection else {
                completion(.failure(PrinterError.notConnected))
                return
            }

            var settingsError: NSError?
            guard let settings = ZebraSDKBridge.getAllSettings(withConnection: conn, outError: &settingsError) else {
                completion(.failure(settingsError ?? PrinterError.settingsFailed("Could not get printer settings")))
                return
            }

            var result: [String?: String?] = [:]
            for (key, value) in settings {
                result[key as? String] = value as? String
            }
            completion(.success(result))
        }
    }
}

// MARK: - Errors

enum PrinterError: Error {
    case notConnected
    case writeFailed
    case connectionFailed(String)
    case statusFailed(String)
    case settingsFailed(String)

    var localizedDescription: String {
        switch self {
        case .notConnected: return "Printer is not connected"
        case .writeFailed: return "Failed to write data to printer"
        case .connectionFailed(let msg): return msg
        case .statusFailed(let msg): return msg
        case .settingsFailed(let msg): return msg
        }
    }
}

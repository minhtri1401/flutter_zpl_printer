#import <Foundation/Foundation.h>
#import <ExternalAccessory/ExternalAccessory.h>

NS_ASSUME_NONNULL_BEGIN

/// Error domain for all ZebraSDKBridge errors.
extern NSString *const ZebraSDKBridgeErrorDomain;

/// Error codes for tracking where failures occur.
typedef NS_ENUM(NSInteger, ZebraErrorCode) {
    ZebraErrorCodeConnectionOpenFailed   = 1001,
    ZebraErrorCodeWriteFailed            = 2001,
    ZebraErrorCodePrinterInstanceFailed  = 3001,
    ZebraErrorCodeStatusQueryFailed      = 3002,
    ZebraErrorCodeSettingsNoResponse     = 4001,
    ZebraErrorCodeSettingsEmptyResponse  = 4002,
};

/// Connection type matching Pigeon's ConnectionType enum.
typedef NS_ENUM(NSInteger, ZebraConnectionType) {
    ZebraConnectionTypeBluetooth = 0,
    ZebraConnectionTypeWifi      = 1,
};

/// Plain C struct for printer status — avoids Swift seeing the ObjC
/// PrinterStatus class (which collides with the Pigeon PrinterStatus struct).
typedef struct {
    BOOL isReadyToPrint;
    BOOL isHeadOpen;
    BOOL isHeadCold;
    BOOL isHeadTooHot;
    BOOL isPaperOut;
    BOOL isRibbonOut;
    BOOL isReceiveBufferFull;
    BOOL isPaused;
    BOOL isPartialFormatInProgress;
    NSInteger labelLengthInDots;
    NSInteger numberOfFormatsInReceiveBuffer;
    NSInteger labelsRemainingInBatch;
} ZebraStatusFields;

/// Thin ObjC wrapper around the Zebra Link-OS SDK.
/// All methods run synchronously — callers must dispatch to a background queue.
@interface ZebraSDKBridge : NSObject

/// Discover Bluetooth MFi accessories already paired via EAAccessoryManager.
/// Returns array of dicts with "name" and "address" (serial number) keys.
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)connectedBluetoothDevices;

/// Discover Wi-Fi printers via local broadcast.
/// Returns array of IP address strings. Never returns nil (returns empty on error).
/// NS_SWIFT_NOTHROW prevents Swift from mapping the NSError** param to throws.
+ (NSArray<NSString *> *)discoverWifiPrintersWithError:(NSError *__autoreleasing *)error
    NS_SWIFT_NOTHROW;

/// Open a connection to a printer.
/// @param address Serial number (BT) or IP address (Wi-Fi).
/// @param type    Connection type.
/// @return Opaque connection token on success, nil on failure (sets outError).
+ (nullable id)openConnectionToAddress:(NSString *)address
                                  type:(ZebraConnectionType)type
                              outError:(NSError *__autoreleasing *)outError
    NS_SWIFT_NOTHROW;

/// Close and release a connection obtained from openConnectionToAddress:type:outError:.
+ (void)closeConnection:(id)connection;

/// Write raw ZPL data through an open connection.
/// Returns NO and sets outError on failure.
+ (BOOL)writeZpl:(NSString *)zpl
      connection:(id)connection
        outError:(NSError *__autoreleasing *)outError
    NS_SWIFT_NOTHROW;

/// Query printer status through an open connection.
/// Returns NO and sets outError on failure.
+ (BOOL)getStatusFields:(ZebraStatusFields *)outFields
             connection:(id)connection
               outError:(NSError *__autoreleasing *)outError
    NS_SWIFT_NOTHROW;

/// Retrieve all printer settings as key-value pairs via the "allcv" SGD command.
/// Returns nil and sets outError on failure.
+ (nullable NSDictionary<NSString *, NSString *> *)getAllSettingsWithConnection:(id)connection
                                                                      outError:(NSError *__autoreleasing *)outError
    NS_SWIFT_NOTHROW;

@end

NS_ASSUME_NONNULL_END

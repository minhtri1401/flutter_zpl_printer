#import "ZebraSDKBridge.h"
#import "MfiBtPrinterConnection.h"
#import "TcpPrinterConnection.h"
#import "NetworkDiscoverer.h"
#import "ZebraPrinterFactory.h"
#import "ZebraPrinterConnection.h"
#import "DiscoveredPrinter.h"
#import "ZebraPrinter.h"
#import "PrinterStatus.h"

NSString *const ZebraSDKBridgeErrorDomain = @"ZebraSDKBridge";

static NSInteger const kDefaultTcpPort = 9100;

@implementation ZebraSDKBridge

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)connectedBluetoothDevices {
    NSMutableArray *devices = [NSMutableArray array];
    EAAccessoryManager *manager = [EAAccessoryManager sharedAccessoryManager];
    for (EAAccessory *acc in manager.connectedAccessories) {
        if ([acc.protocolStrings containsObject:@"com.zebra.rawport"]) {
            NSString *name = acc.name.length > 0 ? acc.name : acc.serialNumber;
            [devices addObject:@{ @"name": name, @"address": acc.serialNumber }];
        }
    }
    return [devices copy];
}

+ (NSArray<NSString *> *)discoverWifiPrintersWithError:(NSError *__autoreleasing *)error {
    NSArray *found = [NetworkDiscoverer localBroadcast:error];
    if (!found) return @[];
    NSMutableArray<NSString *> *addresses = [NSMutableArray array];
    for (DiscoveredPrinter *p in found) {
        [addresses addObject:p.address];
    }
    return [addresses copy];
}

+ (nullable id)openConnectionToAddress:(NSString *)address
                                  type:(ZebraConnectionType)type
                              outError:(NSError *__autoreleasing *)outError {
    id<ZebraPrinterConnection, NSObject> conn;
    if (type == ZebraConnectionTypeBluetooth) {
        conn = [[MfiBtPrinterConnection alloc] initWithSerialNumber:address];
    } else {
        conn = [[TcpPrinterConnection alloc] initWithAddress:address
                                                andWithPort:kDefaultTcpPort];
    }
    if (![conn open]) {
        if (outError) {
            *outError = [NSError errorWithDomain:ZebraSDKBridgeErrorDomain
                                            code:ZebraErrorCodeConnectionOpenFailed
                                        userInfo:@{NSLocalizedDescriptionKey:
                                                       [NSString stringWithFormat:
                                                        @"Failed to open connection to %@", address]}];
        }
        return nil;
    }
    return conn;
}

+ (void)closeConnection:(id)connection {
    id<ZebraPrinterConnection> conn = (id<ZebraPrinterConnection>)connection;
    [conn close];
}

+ (BOOL)writeZpl:(NSString *)zpl
      connection:(id)connection
        outError:(NSError *__autoreleasing *)outError {
    id<ZebraPrinterConnection> conn = (id<ZebraPrinterConnection>)connection;
    NSData *data = [zpl dataUsingEncoding:NSUTF8StringEncoding];
    NSInteger written = [conn write:data error:outError];
    return written >= 0;
}

+ (BOOL)getStatusFields:(ZebraStatusFields *)outFields
             connection:(id)connection
               outError:(NSError *__autoreleasing *)outError {
    id<ZebraPrinterConnection, NSObject> conn =
        (id<ZebraPrinterConnection, NSObject>)connection;
    id<ZebraPrinter, NSObject> printer =
        [ZebraPrinterFactory getInstance:conn error:outError];
    if (!printer) return NO;

    PrinterStatus *s = [printer getCurrentStatus:outError];
    if (!s) return NO;

    outFields->isReadyToPrint             = s.isReadyToPrint;
    outFields->isHeadOpen                 = s.isHeadOpen;
    outFields->isHeadCold                 = s.isHeadCold;
    outFields->isHeadTooHot               = s.isHeadTooHot;
    outFields->isPaperOut                 = s.isPaperOut;
    outFields->isRibbonOut                = s.isRibbonOut;
    outFields->isReceiveBufferFull        = s.isReceiveBufferFull;
    outFields->isPaused                   = s.isPaused;
    outFields->isPartialFormatInProgress  = s.isPartialFormatInProgress;
    outFields->labelLengthInDots          = s.labelLengthInDots;
    outFields->numberOfFormatsInReceiveBuffer = s.numberOfFormatsInReceiveBuffer;
    outFields->labelsRemainingInBatch     = s.labelsRemainingInBatch;
    return YES;
}

+ (nullable NSDictionary<NSString *, NSString *> *)getAllSettingsWithConnection:(id)connection
                                                                      outError:(NSError *__autoreleasing *)outError {
    id<ZebraPrinterConnection, NSObject> conn =
        (id<ZebraPrinterConnection, NSObject>)connection;

    // Send "! U1 getvar "allcv"" to retrieve all configuration values
    NSString *command = @"! U1 getvar \"allcv\"\r\n";
    NSData *cmdData = [command dataUsingEncoding:NSUTF8StringEncoding];
    NSData *response = [conn sendAndWaitForResponse:cmdData
                              withResponseValidator:nil
                                          withError:outError];
    if (!response) return nil;

    NSString *responseStr = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
    if (!responseStr || responseStr.length == 0) {
        if (outError) {
            *outError = [NSError errorWithDomain:ZebraSDKBridgeErrorDomain
                                            code:ZebraErrorCodeSettingsEmptyResponse
                                        userInfo:@{NSLocalizedDescriptionKey:
                                                       @"Empty response from printer"}];
        }
        return nil;
    }

    // Parse lines matching: "key" : "value" (tolerant of whitespace variations)
    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:@"^\"([^\"]+)\"\\s*:\\s*\"(.*)\"$"
                                                         options:0
                                                           error:nil];
    });

    NSMutableDictionary<NSString *, NSString *> *settings = [NSMutableDictionary dictionary];
    NSArray<NSString *> *lines = [responseStr componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length == 0) continue;

        NSTextCheckingResult *match = [regex firstMatchInString:trimmed
                                                        options:0
                                                          range:NSMakeRange(0, trimmed.length)];
        if (!match || match.numberOfRanges < 3) continue;

        NSString *key = [trimmed substringWithRange:[match rangeAtIndex:1]];
        NSString *value = [trimmed substringWithRange:[match rangeAtIndex:2]];
        settings[key] = value;
    }

    return [settings copy];
}

@end

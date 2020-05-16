import Flutter
import UIKit
import Sentry

public class SwiftFlutterSentryPlugin: NSObject, FlutterPlugin {
    private static let SentryDSNKey = "SentryDSN"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "flutter_sentry",
            binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterSentryPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    override init() {
        let dsn = Bundle.main.object(
            forInfoDictionaryKey: SwiftFlutterSentryPlugin.SentryDSNKey)
        if dsn == nil {
            NSException.raise(
                NSExceptionName.invalidArgumentException,
                format:"The value for key %@ is not set in Info.plist",
                arguments: getVaList([
                    Self.SentryDSNKey,
                ]))
        }

        let dsnString = dsn as? String
        if dsnString == nil {
            NSException.raise(
                NSExceptionName.invalidArgumentException,
                format:"The value for key %@ is not a <string> type: %@",
                arguments: getVaList([
                    Self.SentryDSNKey,
                    String(describing: dsn),
                ]))
        }
        
        SentrySDK.start(options: [
            "dsn": dsnString!,
        ])
    }

    public func handle(_ call: FlutterMethodCall,
                       result: @escaping FlutterResult) {
        switch call.method {
        case "nativeCrash":
            SentrySDK.crash()
        default:
           result(FlutterMethodNotImplemented)
        }
    }
}

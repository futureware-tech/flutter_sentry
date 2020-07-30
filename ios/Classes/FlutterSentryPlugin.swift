import Flutter
import UIKit
import Sentry

public class FlutterSentryPlugin: NSObject, FlutterPlugin {
    private static let SentryDSNKey = "SentryDSN"
    private static let SentryEnableAutoSessionTracking =
        "SentryEnableAutoSessionTracking"
    private static let SentrySessionTrackingIntervalMillis =
        "SentrySessionTrackingIntervalMillis"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "flutter_sentry",
            binaryMessenger: registrar.messenger())
        let instance = FlutterSentryPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    override init() {
        guard let dsn = Bundle.main.object(
            forInfoDictionaryKey: FlutterSentryPlugin.SentryDSNKey
        ) else {
            NSException.raise(
                NSExceptionName.invalidArgumentException,
                format:"The value for key %@ is not set in Info.plist",
                arguments: getVaList([
                    Self.SentryDSNKey,
                ]))
            return
        }

        guard let dsnString = dsn as? String else {
            NSException.raise(
                NSExceptionName.invalidArgumentException,
                format:"The value for key %@ is not a <string> type: %@",
                arguments: getVaList([
                    Self.SentryDSNKey,
                    String(describing: dsn),
                ]))
            return
        }

        guard let enableAutoSessionTracking = Bundle.main.object(
            forInfoDictionaryKey:
                FlutterSentryPlugin.SentryEnableAutoSessionTracking
        ) else {
            SentrySDK.start(options: [
                "dsn": dsnString,
            ])
            return
        }

        guard let sessionTrackingIntervalMillis = Bundle.main.object(
            forInfoDictionaryKey:
                FlutterSentryPlugin.SentryEnableAutoSessionTracking
        ) else {
            SentrySDK.start(options: [
                "dsn": dsnString,
                "enableAutoSessionTracking": enableAutoSessionTracking,
            ])
            return
        }

        SentrySDK.start(options: [
            "dsn": dsnString,
            "enableAutoSessionTracking": enableAutoSessionTracking,
            "sessionTrackingIntervalMillis": sessionTrackingIntervalMillis,
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

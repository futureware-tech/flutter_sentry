import Flutter
import UIKit
import Sentry

public class SwiftFlutterSentryPlugin: NSObject, FlutterPlugin {
    private static let SentryDSNKey = "SentryDSN"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_sentry", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterSentryPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    override init() {
        if Client.shared != nil {
            return;
        }

        let dsn = Bundle.main.object(forInfoDictionaryKey: SwiftFlutterSentryPlugin.SentryDSNKey)
        if dsn == nil {
            NSException.raise(NSExceptionName.invalidArgumentException,
                              format:"The value for key %@ is not set in Info.plist",
                              arguments: getVaList([
                                Self.SentryDSNKey,
                              ]))
        }

        let dsnString = dsn as? String
        if dsnString == nil {
            NSException.raise(NSExceptionName.invalidArgumentException,
                              format:"The value for key %@ is not a <string> type: %@",
                              arguments: getVaList([
                                Self.SentryDSNKey,
                                String(describing: dsn),
                              ]))
        }

        do {
            Client.shared = try Client(dsn: dsnString!)
            try Client.shared?.startCrashHandler()
        } catch let error {
            print("Failed to initialize Sentry: \(error)")
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Right now the only method we handle is nativeCrash(), so don't even bother checking.
        // In future we may extend this API with user and context settings.
        if let client = Client.shared {
            client.crash();
        } else {
            result(FlutterError(code: "UNAVAILABLE",
                                message: "Sentry shared client has not been initialized",
                                details: nil))
        }
    }
}

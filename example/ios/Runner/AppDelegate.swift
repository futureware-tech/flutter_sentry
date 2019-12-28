import UIKit
import Flutter
import Sentry

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private let SentryDSNKey = "SentryDSN";

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let dsn = Bundle.main.object(forInfoDictionaryKey: SentryDSNKey);
        if (dsn == nil) {
            NSException.raise(NSExceptionName.invalidArgumentException,
                              format:"The value for key %@ is not set in Info.plist",
                              arguments: getVaList([SentryDSNKey]))
            return false;
        }

        let dsnString = dsn as? String;
        if (dsnString == nil) {
            NSException.raise(NSExceptionName.invalidArgumentException,
                              format:"The value for key %@ is not a <string> type: %@",
                              arguments: getVaList([SentryDSNKey, String(describing: dsn)]))
        }

        do {
            Client.shared = try Client(dsn: dsnString!)
            try Client.shared?.startCrashHandler()
        } catch let error {
            print("Failed to initialize Sentry: \(error)")
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}

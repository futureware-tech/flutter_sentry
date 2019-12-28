import Flutter
import UIKit
import Sentry

public class SwiftFlutterSentryPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_sentry", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterSentryPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    Client.shared?.crash()
  }
}

#import "FlutterSentryPlugin.h"
#if __has_include(<flutter_sentry/flutter_sentry-Swift.h>)
#import <flutter_sentry/flutter_sentry-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_sentry-Swift.h"
#endif

@implementation FlutterSentryPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterSentryPlugin registerWithRegistrar:registrar];
}
@end

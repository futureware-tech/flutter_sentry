[![pub package](https://img.shields.io/pub/v/flutter_sentry.svg)](https://pub.dev/packages/flutter_sentry)
[![flutter build](https://github.com/futureware-tech/flutter_sentry/workflows/flutter/badge.svg?branch=master&event=push)](https://github.com/futureware-tech/flutter_sentry/actions?query=workflow%3Aflutter+branch%3Amaster)
[![code coverage](https://codecov.io/gh/futureware-tech/flutter_sentry/branch/master/graph/badge.svg)](https://codecov.io/gh/futureware-tech/flutter_sentry)

Note on package ambiguity:

- [`sentry`](https://pub.dev/packages/sentry) package is a pure Dart
  implementation of Sentry.io client, allowing users to customize and extend
  their reports in Dart, regardless of framework choice;

- [`sentry_flutter`](https://pub.dev/packages/sentry_flutter) is a new package
  offered by Sentry, which supports integration with native platforms (such as
  iOS, Android and Web) where Flutter applications can run. It is getting
  feature parity (and in some parts, superiority) to this package;

- [`flutter_sentry`](https://pub.dev/packages/flutter_sentry) (the package you
  are looking at) is a stop gap solution while Sentry team has not offered an
  implementation that would support Flutter ecosystem (such as automatically
  reporting device configuration in Dart and tracking debug logs and navigation
  events). It still has some features that `sentry_flutter` does not yet offer,
  but it may become obsolete in the future if the Sentry team decides to
  implement missing features.

  `flutter_sentry` uses `sentry` package to communicate with Sentry.io.

## Setup

1. Add `flutter_sentry` to your `pubspec.yaml`:

   ```yaml
   dependencies:
     flutter_sentry: ^0.8.2
     # To use classes provided by sentry package (e.g. User).
     sentry: any
   ```

2. Find out a DSN value from Sentry.io and add it to native platforms:

   **NOTE**: if you forget to add DSN to the platform code, or do it
   incorrectly, the application will encounter a
   [fatal crash](https://github.com/getsentry/sentry-android/pull/200) on
   startup on that platform.

   - iOS: in `ios/Runner/Info.plist`:

     ```xml
     <dict>
       ... existing configuration parameters ...
       <key>SentryDSN</key>
       <string>value you got from sentry.io</string>
     </dict>
     ```

   - Android: in `android/app/src/main/AndroidManifest.xml`:

     ```xml
     <application>
       <meta-data
           android:name="io.sentry.dsn"
           android:value="value you got from sentry.io" />
     ```

     You can also enable debug logging for Sentry Android library if it's not
     working as intended:

     ```xml
       <meta-data
           android:name="io.sentry.debug"
           android:value="true" />
     ```

     **NOTE**: make sure to add `<meta-data>` tag directly under `<application>`
     (and not for example `<activity>`).

3. Finally, wrap your `runApp()` call in `FlutterSentry.wrap()` like this:

   ```dart
   import 'package:flutter_sentry/flutter_sentry.dart';

   Future<void> main() => FlutterSentry.wrap(
        () async {
          // Optionally other initializers, like Firebase.

          runApp(App());
        },
        dsn: 'value you got from sentry.io',
      );
   ```

## Environments

It is sensible to have error reporting configured for debug builds similar to
production. This makes sure that error reporting works as expected in all
environments, and provides consistency.

You may be even sharing the same DSN (pointer to Sentry project) between debug
and production environments. If you don't have to worry about Sentry quotas,
this is probably a reasonable decision for smaller projects.

However, you still don't want to be alerted about each and every error that
occurs during debugging. `FlutterSentry.wrap` helps avoiding this by setting
`environment` attribute of error reports according to the environment your
Flutter application is running in: `release`, `debug` or `profile`. In your
Sentry project's "Alerts" section you can configure to only get notified about
`release` issues.

One exception may be
[Flutter Driver](https://flutter.dev/docs/cookbook/testing/integration/introduction)
tests running on CI environment. Pre-release tests are often one of the last
lines of defense before releasing an application to production. Background
failures in such tests may be uncaught (because tests are often focused on a
specific flow) but should still alert you.

For such exceptions, `flutter_sentry` allows overriding autodetected environment
by running driver with `sentry.environment` override:

```
$ flutter drive --dart-define=sentry.environment=ci ...
```

For a higher degree of control, you can turn reporting on or off through the
`enable` parameter. Passing `enable: false` will avoid passing errors to the
Sentry library, but errors are still logged to the console.

```dart
FlutterSentry.wrap(
  () async {
    runApp(App());
  },
  enable: !kDebugMode,
);
```

## Release Health tracking

One of the most recent additions to Sentry.io was
[Release Health](https://docs.sentry.io/workflow/releases/health/) tracking.
Learn more how to set it up for
[Android](https://docs.sentry.io/platforms/android/#release-health) and
[iOS](https://docs.sentry.io/platforms/cocoa/#release-health). This feature does
not yet have any Flutter specific integrations.

**NOTE**: Session tracking is disabled by default and the timeout for a session
defaults to 30000 milliseconds (30 seconds).

- iOS: in `ios/Runner/Info.plist`:

  ```xml
  <dict>
    ... existing configuration parameters ...
    <key>SentryEnableAutoSessionTracking</key>
    <true/>
    <key>SentrySessionTrackingIntervalMillis</key>
    <integer>60000</integer>
  </dict>
  ```

- Android: in `android/app/src/main/AndroidManifest.xml`:

  ```xml
  <application>
    <meta-data
        android:name="io.sentry.session-tracking.enable"
        android:value="true"/>
    <meta-data
        android:name="io.sentry.session-tracking.timeout-interval-millis"
        android:value="60000" />
  ```

## Reporting custom events

`FlutterSentry.wrap()` already reports `debugPrint` and `print` calls to Sentry
via breadcrumbs.

If you'd like to report a non-fatal exception manually, you can use
`FlutterSentry.instance.captureException()` method, for example:

```dart
FlutterSentry.wrap(() {
  // This will report a non-fatal event to Sentry, including current stack
  // trace, device and application info.
  FlutterSentry.instance.captureException(
    exception: Exception('Things went wrong'),
  );

  // This will report a non-fatal event to Sentry, including current stack
  // trace, device and application info.
  FlutterSentry.instance.captureException(
      exception: Exception('Things went wrong'),
      extra: {
          // Free form values to attach to the event.
          'application state': 'unstable',
      },
  );
});
```

## Why do I have to specify DSN in multiple places?

You might be wondering why a DSN value can't be specified in a single place and
then exchanged between platforms and Dart/Flutter code via a
[MethodChannel](https://flutter.dev/platform-channels/). The reason for that is,
native code and Flutter initialize in parallel, before MethodChannel is
available, and if a crash happens before MethodChannel is ready... that part of
application is on its own.

That said, we want to minimize the installation burden. While the plugin is
still in development, we may eventually introduce a way to configure the value
once and have it copied to all platforms at build time. Stay tuned!

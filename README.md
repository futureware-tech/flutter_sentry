[![pub package](https://img.shields.io/pub/v/flutter_sentry.svg)](https://pub.dev/packages/flutter_sentry)
[![flutter build](https://github.com/dasfoo/flutter_sentry/workflows/flutter/badge.svg?branch=master&event=push)](https://github.com/dasfoo/flutter_sentry/actions?query=workflow%3Aflutter+branch%3Amaster)
[![code coverage](https://codecov.io/gh/dasfoo/flutter_sentry/branch/master/graph/badge.svg)](https://codecov.io/gh/dasfoo/flutter_sentry)

**NOTE**: _While [`sentry`](https://pub.dev/packages/sentry) package provides a
low-level functionality to report exceptions from Dart/Flutter code,
`flutter_sentry` plugin (which also uses `sentry` package behind the scenes!)
aims at full integration with Flutter ecosystem, automatically including Flutter
application details in reports and catching crashes in native code, including
other Flutter plugins and Flutter itself_.

## Setup

1. Add `flutter_sentry` to your `pubspec.yaml`:

   ```yaml
   dependencies:
     flutter_sentry: ^0.4.0
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

## Release Health tracking

One of the most recent additions to Sentry.io was
[Release Health](https://docs.sentry.io/workflow/releases/health/) tracking.
Learn more how to set it up for
[Android](https://docs.sentry.io/platforms/android/#release-health) and
[iOS](https://docs.sentry.io/platforms/cocoa/#release-health). This feature does
not yet have any Flutter specific integrations.

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

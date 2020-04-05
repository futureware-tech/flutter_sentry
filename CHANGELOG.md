## 0.3.3

- Always add `stackTrace` for `captureException`, using `StackTrace.current` if
  unset.
- Put `ErrorSummary.value` diagnostics node into `message` when `FlutterError`
  is passed to `captureException`.

## 0.3.2

- Fix detection of `flutter_driver` for events other than the first.
- Add locale to `environmentAttributes` in `FlutterSentry.wrap()`.

## 0.3.1

- Do not report "arguments: null" in breadcrumb for a route without arguments.
- Add `FlutterSentry.initializeWithClient()` method to share an existing
  `SentryClient` and to use in tests.
- Add `extra` to `FlutterSentry.captureException()` for supplying additional
  event-related data.

## 0.3.0

- Add timezone and screen dimensions to report.
- Do not require `FlutterSentry.wrap<T>()` template parameter `T` to be a
  `Future`.
- Intercept `print()` via `ZoneSpecification` instead of overriding
  `debugPrint()` which is only a wrapper around `print()`.
- Add `userContext` on `FlutterSentry.instance` which allows setting custom
  context. It does not propagate to platform code (yet), so fatal exceptions
  will still lack this data.
- Try to get most recent device parameters (such as screen size) at the time of
  reporting an error, and fall back to the values fetched at `initialize()`.
- Use `FlutterSentry.instance.breadcrumbs` as a breadcrumb tracker for navigator
  observer, if unspecified.
- Add "app" context (including app name and version) to events reported via
  `captureException()`.
- Add "os" context to events reported via `captureException()`.
- Detect "driver" environment for `flutter_driver`.

## 0.2.1

- Update README with new `flutter_sentry` version.
- Filter `package:flutter` stack trace frames by default.
- Remove the use of deprecated method `getFlutterEngine`.

## 0.2.0

- Intercept `debugPrint()` in `wrap()` and add the message to breadcrumbs for
  the next event to upload.
- Enable environment attributes in Dart exceptions.

## 0.1.0

- Remove `pubspec.lock` from version control.
- Add FlutterSentry.breadcrumbs tracker to save a limited number of most recent
  breadcrumbs, which will be sent to Sentry.io with the next error report.
- Add FlutterSentryNavigatorObserver allowing to track navigation events in
  application.
- Send device information to Sentry.io when reporting an event.

## 0.0.2

- Add initilize method with dsn to init SentryClient.
- Make FlutterSentry a Singleton.

## 0.0.1+2

- Update examples in README.
- Update plugin description.
- Add API documentation.

## 0.0.1+1

- Add badges to README.

## 0.0.1

- Initial release.

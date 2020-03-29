## Unreleased

- Add timezone and screen dimensions to report.
- Do not require `FlutterSentry.wrap<T>()` template parameter `T` to be a
  `Future`.
- Intercept `print()` via `ZoneSpecification` instead of overriding
  `debugPrint()` which is only a wrapper around `print()`.
- Add `userContext` on `FlutterSentry.instance` which allows setting custom
  context. It does not propagate to platform code (yet), so fatal exceptions
  will still lack this data.

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

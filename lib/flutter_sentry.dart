import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';

import 'src/breadcrumb_tracker.dart';
import 'src/contexts_cache.dart' as contexts_cache;

export 'src/navigator_observer.dart' show FlutterSentryNavigatorObserver;

/// API entrypoint for Sentry.io Flutter plugin. Start using Sentry.io by
/// calling either [initialize] or [wrap] static methods.
class FlutterSentry {
  FlutterSentry._(this._sentry);

  static const MethodChannel _channel = MethodChannel('flutter_sentry');
  static FlutterSentry _instance;
  static bool _cachedFirebaseTestLab;

  final SentryClient _sentry;

  /// Enable reporting to Sentry. This can be used to disable reporting, in
  /// debug environment for example. Does not disable printing errors to the
  /// console. Defaults to `true`.
  bool enabled = true;

  /// Hook when capturing an Exception. If return non-null value, the
  /// actually captured exception and stack trace will be the returned one.
  /// If return null, the exception will be ignore.
  ExceptionAndStackTrace Function({dynamic exception, dynamic stackTrace})
    captureExceptionPreHook;

  /// Assignable user-related properties which will be attached to every report
  /// created via [captureException] (this includes events reported by [wrap]).
  User userContext;

  /// Breadcrumbs collected so far for reporting in the next event.
  // This type is inferred: https://github.com/dart-lang/linter/issues/1319.
  // ignore: type_annotate_public_apis
  final breadcrumbs = BreadcrumbTracker();

  /// Cause a crash on the native platform (Android or iOS). Unlike most Dart
  /// [Exception]s, such crashes are usually fatal for application. The use case
  /// here is to cause a fatal crash and test reporting of this edge condition
  /// to Sentry.io.
  ///
  /// NOTE: if native Sentry client has failed to initialize, this method throws
  /// a Dart exception and does nothing (on iOS) or simply crashes the app
  /// without reporting to Sentry.io (on Android).
  static Future<void> nativeCrash() => _channel.invokeMethod('nativeCrash');

  /// Return `true` if running under Firebase Test Lab (includes pre-launch
  /// report environment) on Android, `false` otherwise.
  static Future<bool> isFirebaseTestLab() async =>
      _cachedFirebaseTestLab ??= Platform.isAndroid &&
          await _channel.invokeMethod<bool>('getFirebaseTestLab');

  /// A wrapper function for `runApp()` application code. It intercepts few
  /// different error conditions:
  ///
  /// - uncaught exceptions in the zone;
  /// - uncaught exceptions that has been propagated to the current Dart
  ///   isolate;
  /// - FlutterError errors (such as layout errors);
  ///
  /// and reports them to Sentry.io.
  ///
  /// Note that this function calls for [FlutterSentry.initialize], and
  /// therefore cannot be used more than once, or in combination with
  /// [FlutterSentry.initialize].
  ///
  /// flutter_driver users: keep `enableFlutterDriverExtension()` call outside
  /// of the `wrap()`.
  static T wrap<T>(
    T Function() f, {
    @required String dsn,
    bool enable = true,
  }) {
    var printing = false;
    return runZoned<T>(
      () {
        WidgetsFlutterBinding.ensureInitialized();
        final window = WidgetsBinding.instance.window;

        // initialize() calls for WidgetsFlutterBinding.ensureInitialized(),
        // which is necessary to initialize Flutter method channels so that
        // our plugin can call into the native code. It also must be in the same
        // zone as the app: https://github.com/flutter/flutter/issues/42682.
        initialize(
          dsn: dsn,
          environmentAttributes: Event(
            environment: const String.fromEnvironment(
              'sentry.environment',
              defaultValue:
                  kReleaseMode ? 'release' : kProfileMode ? 'profile' : 'debug',
            ),
            extra: <String, dynamic>{
              // This should really go into one of Contexts, but there's just no
              // place for it there!
              'locale': window.locale.toString(),
            },
          ),
        );

        _instance.enabled = enable;

        FlutterError.onError = (details) {
          FlutterError.dumpErrorToConsole(details);
          instance.captureException(
            exception: details.exception,
            stackTrace: details.stack,
          );
        };

        Isolate.current.addErrorListener(
          RawReceivePort((dynamic errorAndStacktrace) {
            // This must be a 2-element list per documentation:
            // https://api.dartlang.org/stable/2.7.0/dart-isolate/Isolate/addErrorListener.html
            final dynamic error = errorAndStacktrace[0],
                stackTrace = errorAndStacktrace[1];
            // RawReceivePort is exempt from zones, but we don't need this error
            // message as a breadcrumb, anyway.
            debugPrint(
                'Uncaught error in Flutter isolate: $error\n$stackTrace');
            instance.captureException(
              exception: error,
              stackTrace: stackTrace is String
                  ? StackTrace.fromString(stackTrace)
                  : null,
            );
          }).sendPort,
        );

        return f();
      },
      zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) {
        // One should be careful to not introduce any print() calls inside this
        // block, as they will create an infinite recursion.
        if (printing) {
          // Oops. Looks like we got ourselves into recursion, i.e. some code in
          // try..finally below calls (maybe indirectly) print().
          parent.print(
              zone,
              'ERROR! ERROR! ERROR! Recursion in zoneSpecification.print(). '
              'When printing: $line');
          return;
        }

        printing = true;
        try {
          parent.print(self, line);
          instance.breadcrumbs.add(Breadcrumb(
            line,
            DateTime.now().toUtc(),
            category: 'print',
          ));
        } finally {
          printing = false;
        }
      }),
      // This has been prematurely marked deprecated -- it's a stable 2.7 API
      // and the replacement has been introduced in the same version along with
      // @Deprecated annotation.
      // ignore: deprecated_member_use
      onError: (Object exception, StackTrace stackTrace) {
        debugPrint('Uncaught error in zone: $exception\n$stackTrace');
        instance.captureException(
          exception: exception,
          stackTrace: stackTrace,
        );
      },
    );
  }

  /// Reports the [exception] and optionally its [stackTrace] to Sentry.io. It
  /// also reports device info and [breadcrumbs].
  Future<SentryResponse> captureException({
    @required dynamic exception,
    dynamic stackTrace,
    Map<String, dynamic> extra,
  }) {
    if (!enabled) {
      return Future.value();
    }

    if (captureExceptionPreHook != null) {
      final transformed = captureExceptionPreHook.call(
          exception: exception, stackTrace: stackTrace);
      if (transformed == null) {
        return Future.value();
      }else{
        exception = transformed.exception;
        stackTrace = transformed.stackTrace;
      }
    }

    if (stackTrace == null && exception is Error) {
      stackTrace = exception.stackTrace;
    }
    stackTrace ??= StackTrace.current;

    final event = Event(
      exception: exception,
      // Workaround for https://github.com/flutter/flutter/issues/54038.
      message: exception is FlutterError
          ? exception.diagnostics
              .whereType<ErrorSummary>()
              .map((node) => node.value?.join('\n'))
              .where((nodeValue) => nodeValue != null)
              .join('\n')
          : null,
      stackTrace: stackTrace,
      release: _sentry.environmentAttributes?.release ??
          contexts_cache.defaultReleaseString(),
      breadcrumbs: breadcrumbs.breadcrumbs.toList(),
      userContext: userContext,
      contexts: contexts_cache.currentContexts(),
      extra: extra,
    );
    return _sentry.capture(event: event, stackFrameFilter: stackFrameFilter);
  }

  /// Filter for stack trace frames, applied after `Frame` objects are converted
  /// to JSON representation but before they are sent to Sentry. See
  /// [SentryClient.capture] for more information.
  List<Map<String, dynamic>> Function(List<Map<String, dynamic>>)
      stackFrameFilter = defaultStackFrameFilter;

  /// Default filtering for Sentry JSON stack frames with Flutter-oriented
  /// implementation, such as marking Flutter part of stacktrace as framework
  /// stack trace to unclutter Sentry.io interface.
  static List<Map<String, dynamic>> defaultStackFrameFilter(
          List<Map<String, dynamic>> stack) =>
      stack
          .map<Map<String, dynamic>>((frame) =>
              frame['abs_path'].toString().startsWith('package:flutter/')
                  ? (frame..['in_app'] = false)
                  : frame)
          .toList();

  /// Return the configured instance of [FlutterSentry] after it has been
  /// initialized with [initialize] method, or `null` if the instance has not
  /// been initialized.
  static FlutterSentry get instance => _instance;

  /// Initialize [FlutterSentry] with [dsn] received from Sentry.io, making an
  /// instance available via [instance] property. It is an [Error] to call this
  /// method more than once during the application lifecycle.
  ///
  /// [environmentAttributes] is optional and contains [Event] attributes that
  /// are automatically mixed into all events captured through this client.
  /// This event should contain static values that do not change from
  /// event to event, for example, app environment (debug, production, profile),
  /// the version of Dart/Flutter SDK, etc.
  ///
  /// flutter_driver users: make sure to call `enableFlutterDriverExtension()`
  /// before `initialize()`.
  static void initialize({@required String dsn, Event environmentAttributes}) {
    _ensureNotInitialized();
    initializeWithClient(
      SentryClient(dsn: dsn, environmentAttributes: environmentAttributes),
    );
  }

  /// Initialize [FlutterSentry] with an existing and configured [SentryClient].
  /// Useful for tests. For the rest of semantics, see [initialize].
  static void initializeWithClient(SentryClient sentryClient) {
    _ensureNotInitialized();
    _instance = FlutterSentry._(sentryClient);
    contexts_cache.prefetch();
  }

  static void _ensureNotInitialized() {
    if (_instance != null) {
      throw StateError('FlutterSentry has already been initialized');
    }
  }
}

class ExceptionAndStackTrace {
  dynamic exception;
  dynamic stackTrace;
}

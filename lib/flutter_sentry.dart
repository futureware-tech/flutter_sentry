import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
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

  /// Enable reporting to Sentry.io from Dart. DEPRECATED. This can be used to
  /// disable reporting, in debug environment for example. Does not disable
  /// [captureExceptionFilter], printing errors to the console or native
  /// platform reporting. Defaults to `true`.
  @Deprecated('Use captureExceptionAction instead.')
  bool get enabled =>
      captureExceptionAction == CaptureExceptionAction.logAndReport;

  @Deprecated('Set captureExceptionAction instead.')
  set enabled(bool value) => captureExceptionAction = value
      ? CaptureExceptionAction.logAndReport
      : CaptureExceptionAction.logOnly;

  /// Default action for [captureException] to take. It can be used to disable
  /// reporting, for example, in debug environment. [captureExceptionFilter] is
  /// still called, and its return value overrides what is set here.
  ///
  /// This setting has no effect on platform-specific exception reports.
  CaptureExceptionAction captureExceptionAction =
      CaptureExceptionAction.logAndReport;

  /// If not `null`, called every time [captureException] is invoked, which
  /// includes exceptions intercepted by [wrap]. The `captureParameters` can be
  /// modified and will affect what is logged and reported to Sentry.io. The
  /// return value overrides [captureExceptionAction] set in this instance.
  ///
  /// NOTE: this method is called after parameters to [captureException] have
  /// been processed; for example, [CaptureExceptionParameters.stackTrace] may
  /// be populated with current stack trace if the input value has been `null`.
  /// Consequently, no additional mangling of the parameters is performed after
  /// this method.
  CaptureExceptionAction Function(CaptureExceptionParameters captureParameters)
      captureExceptionFilter;

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
    @Deprecated('Set FlutterSentry.instance.captureExceptionAction in wrap().')
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

        // Supports deprecated parameters to wrap().
        // ignore: deprecated_member_use_from_same_package
        _instance.enabled = enable;

        FlutterError.onError = (details) {
          FlutterError.dumpErrorToConsole(details);
          instance.captureException(
            exception: details.exception,
            stackTrace: details.stack,
            // TODO(dotdoom): add FlutterError details to extra.
            logPrefix: 'More details from FlutterError.onError: ',
          );
        };

        Isolate.current.addErrorListener(
          RawReceivePort((dynamic errorAndStacktrace) {
            // This must be a 2-element list per documentation:
            // https://api.dartlang.org/stable/2.7.0/dart-isolate/Isolate/addErrorListener.html
            final dynamic error = errorAndStacktrace[0],
                stackTrace = errorAndStacktrace[1];
            instance.captureException(
              exception: error,
              stackTrace: stackTrace is String
                  ? StackTrace.fromString(stackTrace)
                  : null,
              logPrefix: 'Uncaught error in Flutter isolate: ',
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
        instance.captureException(
          exception: exception,
          stackTrace: stackTrace,
          logPrefix: 'Uncaught error in zone: ',
        );
      },
    );
  }

  /// Reports the [exception] and optionally its [stackTrace] to Sentry.io. It
  /// also reports device info and [breadcrumbs].
  Future<SentryResponse> captureException({
    @required final dynamic exception,
    final dynamic stackTrace,
    final Map<String, dynamic> extra,
    String logPrefix,
  }) {
    final parameters = CaptureExceptionParameters._(
      exception: exception,
      stackTrace: stackTrace,
      extra: extra,
    );
    if (parameters.stackTrace == null && parameters.exception is Error) {
      parameters.stackTrace = exception.stackTrace;
    }
    if (parameters.stackTrace == null ||
        parameters.stackTrace.toString().isEmpty) {
      // If the stack trace has been forgotten or is empty (as Future.timeout
      // often does), fall back to current stack trace, which should give a clue
      // of at least where the exception was caught.
      parameters.stackTrace ??= StackTrace.current;
    }

    var action = captureExceptionAction;
    if (captureExceptionFilter != null) {
      action = captureExceptionFilter(parameters);
    }

    if (action != CaptureExceptionAction.ignore) {
      logPrefix ??= '';
      debugPrint('$logPrefix${parameters.exception}\n${parameters.stackTrace}');
    }
    if (action != CaptureExceptionAction.logAndReport) {
      return Future.value();
    }

    final event = Event(
      exception: parameters.exception,
      stackTrace: parameters.stackTrace,
      release: _sentry.environmentAttributes?.release ??
          contexts_cache.defaultReleaseString(),
      breadcrumbs: breadcrumbs.breadcrumbs.toList(),
      userContext: userContext,
      contexts: contexts_cache.currentContexts(),
      extra: parameters.extra,
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

  /// DO NOT USE. For [FlutterSentry] internal testing only. Clears the instance
  /// of this [FlutterSentry]. This does not affect how interaction with native
  /// platform is done, which is the reason why only one instance should be
  /// available for user at a time (to avoid confusion).
  @visibleForTesting
  static void deinitialize() {
    _instance = null;
  }

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

/// Parameters passed to [FlutterSentry.captureException].
class CaptureExceptionParameters {
  CaptureExceptionParameters._({
    this.exception,
    this.stackTrace,
    this.extra,
  });

  /// Reported exception. See [FlutterSentry.captureException].
  dynamic exception;

  /// Reported stack trace. See [FlutterSentry.captureException].
  dynamic stackTrace;

  /// Reported extra tags. See [FlutterSentry.captureException].
  Map<String, dynamic> extra;
}

/// Action to be performed by [FlutterSentry.captureException].
enum CaptureExceptionAction {
  /// Log the exception via [debugPrint] and report to Sentry.io.
  logAndReport,

  /// Only log the exception via [debugPrint] but do not report to Sentry.io.
  logOnly,

  /// Completely ignore this exception instance.
  ignore,
}

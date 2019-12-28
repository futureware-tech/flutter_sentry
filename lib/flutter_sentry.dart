import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';

class FlutterSentry {
  static const MethodChannel _channel = const MethodChannel('flutter_sentry');

  static Future<void> nativeCrash() => _channel.invokeMethod('nativeCrash');

  static Future<T> wrap<T>(Future<T> Function() f, {@required String dsn}) {
    final sentry = SentryClient(dsn: dsn);
    return runZoned<Future<T>>(() async {
      // This is necessary to initialize Flutter method channels so that
      // our plugin can call into the native code. It also must be in the same
      // zone as the app: https://github.com/flutter/flutter/issues/42682.
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.dumpErrorToConsole(details);
        sentry.captureException(
          exception: details.exception,
          stackTrace: details.stack,
        );
      };

      Isolate.current.addErrorListener(RawReceivePort((pair) async {
        final List<String> errorAndStacktrace = pair;
        debugPrint('Uncaught error in Flutter isolate: $errorAndStacktrace');
        await sentry.captureException(
          exception: errorAndStacktrace.first,
          stackTrace: errorAndStacktrace.last == null
              ? null
              : StackTrace.fromString(errorAndStacktrace.last),
        );
      }).sendPort);

      return await f();
    }, onError: (exception, stackTrace) {
      debugPrint('Uncaught error in zone: $exception\n$stackTrace');
      sentry.captureException(
        exception: exception,
        stackTrace: stackTrace,
      );
    });
  }
}

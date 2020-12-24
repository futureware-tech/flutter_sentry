import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sentry/flutter_sentry.dart';
import 'package:flutter_sentry/src/contexts_cache.dart';
import 'package:flutter_test/flutter_test.dart' as flutter;
import 'package:mockito/mockito.dart';
import 'package:package_info/package_info.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group('FlutterSentry', () {
    setUpAll(() {
      flutter.TestWidgetsFlutterBinding.ensureInitialized();
      packageInfo = PackageInfo();
    });

    tearDown(FlutterSentry.deinitialize);

    test('defaultStackFrameFilter marks "flutter" frames as not in_app', () {
      expect(
        FlutterSentry.defaultStackFrameFilter([
          <String, dynamic>{'abs_path': 'package:tedious_monsters/alarm.dart'},
          <String, dynamic>{'abs_path': 'package:flutter_helper/index.dart'},
          <String, dynamic>{'abs_path': 'package:flutter/flutter.dart'},
          <String, dynamic>{'abs_path': 'package:flutter/init.dart'},
          <String, dynamic>{'abs_path': 'main.dart'},
        ]),
        [
          {'abs_path': 'package:tedious_monsters/alarm.dart'},
          {'abs_path': 'package:flutter_helper/index.dart'},
          {'in_app': false, 'abs_path': 'package:flutter/flutter.dart'},
          {'in_app': false, 'abs_path': 'package:flutter/init.dart'},
          {'abs_path': 'main.dart'},
        ],
      );
    });

    test('does not allow to initialize more than once', () {
      FlutterSentry.initializeWithClient(_MockSentryClient());
      expect(
        () => FlutterSentry.initializeWithClient(_MockSentryClient()),
        throwsA(const TypeMatcher<StateError>()),
      );
    });

    test('respects captureExceptionAction', () async {
      final client = _MockSentryClient();
      final globals = _MockGlobals();
      debugPrint = globals.debugPrint;
      FlutterSentry.initializeWithClient(client);

      await FlutterSentry.instance.captureException(exception: 'log&report');
      verify(client.capture(
        event: anyNamed('event'),
        stackFrameFilter: anyNamed('stackFrameFilter'),
      )).called(1);
      verify(globals.debugPrint(argThat(startsWith('log&report\n')))).called(1);

      FlutterSentry.instance.captureExceptionAction =
          CaptureExceptionAction.logOnly;
      await FlutterSentry.instance.captureException(exception: 'logonly');
      verifyNever(client.capture(
        event: anyNamed('event'),
        stackFrameFilter: anyNamed('stackFrameFilter'),
      ));
      verify(globals.debugPrint(argThat(startsWith('logonly\n')))).called(1);

      FlutterSentry.instance.captureExceptionAction =
          CaptureExceptionAction.ignore;
      await FlutterSentry.instance.captureException(exception: 'ignored');
      verifyNever(client.capture(
        event: anyNamed('event'),
        stackFrameFilter: anyNamed('stackFrameFilter'),
      ));
      verifyNever(globals.debugPrint(argThat(startsWith('ignored\n'))));

      verifyNoMoreInteractions(globals);
    });

    test('processes captureExceptionFilter', () async {
      final client = _MockSentryClient();
      final globals = _MockGlobals();
      debugPrint = globals.debugPrint;
      FlutterSentry.initializeWithClient(client);

      FlutterSentry.instance.captureExceptionFilter = (p) {
        p.extra = <String, bool>{'passed': true};
        return FlutterSentry.instance.captureExceptionAction;
      };
      await FlutterSentry.instance.captureException(exception: 'error');
      expect(
        verify(client.capture(
          event: captureAnyNamed('event'),
          stackFrameFilter: anyNamed('stackFrameFilter'),
        )).captured[0].extra,
        containsPair('passed', true),
      );
      verify(globals.debugPrint(argThat(startsWith('error\n')))).called(1);

      FlutterSentry.instance.captureExceptionFilter = (p) {
        p.exception = 'filtered';
        return CaptureExceptionAction.logOnly;
      };
      await FlutterSentry.instance.captureException(exception: 'unexpected');
      verifyNever(client.capture(
        event: anyNamed('event'),
        stackFrameFilter: anyNamed('stackFrameFilter'),
      ));
      verifyNever(globals.debugPrint(argThat(contains('unexpected'))));
      verify(globals.debugPrint(argThat(startsWith('filtered\n')))).called(1);

      verifyNoMoreInteractions(globals);
    });

    test('calls into MethodChannel for native code', () async {
      const channel = MethodChannel('flutter_sentry');
      final globals = _MockGlobals();
      channel.setMockMethodCallHandler(globals.methodChannelCall);
      when(globals.methodChannelCall(any)).thenAnswer((_) async => true);
      await FlutterSentry.nativeCrash();
      expect(
        verify(globals.methodChannelCall(captureAny)).captured[0].method,
        'nativeCrash',
      );
      verifyNoMoreInteractions(globals);
    });

    test('passthrough or guess stack trace correctly', () async {
      final client = _MockSentryClient();
      FlutterSentry.initializeWithClient(client);
      final trace = StackTrace.fromString('test_stack_trace');

      await FlutterSentry.instance.captureException(
        exception: _ErrorWithStacktrace(trace),
      );
      expect(
        verify(client.capture(
          event: captureAnyNamed('event'),
          stackFrameFilter: anyNamed('stackFrameFilter'),
        )).captured[0].stackTrace,
        trace,
        reason: 'Should pick stack trace from Error.',
      );

      await FlutterSentry.instance.captureException(
        exception: Exception(),
      );
      expect(
        verify(client.capture(
          event: captureAnyNamed('event'),
          stackFrameFilter: anyNamed('stackFrameFilter'),
        )).captured[0].stackTrace.toString(),
        contains('flutter_sentry_test.dart'),
        reason: '"null" should fall back to current stack trace.',
      );

      await FlutterSentry.instance.captureException(
        exception: Exception(),
        stackTrace: StackTrace.empty,
      );
      expect(
        verify(client.capture(
          event: captureAnyNamed('event'),
          stackFrameFilter: anyNamed('stackFrameFilter'),
        )).captured[0].stackTrace.toString(),
        contains('flutter_sentry_test.dart'),
        reason: 'Empty trace should fall back to current stack trace.',
      );

      await FlutterSentry.instance.captureException(
        exception: Exception(),
        stackTrace: trace,
      );
      expect(
        verify(client.capture(
          event: captureAnyNamed('event'),
          stackFrameFilter: anyNamed('stackFrameFilter'),
        )).captured[0].stackTrace,
        trace,
        reason: 'Should take the trace as reported.',
      );
    });
  });
}

class _MockSentryClient extends Mock implements SentryClient {}

class _MockGlobals extends Mock {
  void debugPrint(String arg, {int wrapWidth});
  Future<dynamic> methodChannelCall(MethodCall call);
}

@immutable
class _ErrorWithStacktrace implements Error {
  const _ErrorWithStacktrace(this.stackTrace);

  @override
  final StackTrace stackTrace;
}

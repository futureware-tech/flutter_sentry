import 'package:flutter_sentry/flutter_sentry.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group('FlutterSentry', () {
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
  });
}

class _MockSentryClient extends Mock implements SentryClient {}

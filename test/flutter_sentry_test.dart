import 'package:flutter_sentry/flutter_sentry.dart';
import 'package:test/test.dart';

void main() {
  group('defaultStackFrameFilter', () {
    test('marks frames from "flutter" package as not in_app', () {
      expect(
        FlutterSentry.defaultStackFrameFilter([
          {'abs_path': 'package:tedious_monsters/alarm.dart'},
          {'abs_path': 'package:flutter_helper/index.dart'},
          {'abs_path': 'package:flutter/flutter.dart'},
          {'abs_path': 'package:flutter/init.dart'},
          {'abs_path': 'main.dart'},
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
  });
}

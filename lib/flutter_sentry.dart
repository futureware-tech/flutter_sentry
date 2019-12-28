import 'dart:async';

import 'package:flutter/services.dart';

class FlutterSentry {
  static const MethodChannel _channel = const MethodChannel('flutter_sentry');

  static Future<void> nativeCrash() => _channel.invokeMethod('nativeCrash');
}

import 'dart:io';

import 'package:device_info/device_info.dart';
import 'package:flutter/widgets.dart';

/// A class to fetch and keep cache of "device" context of `FlutterEvent`.
class DeviceContext {
  /// Creates a snapshot of the current "device" context cache, along with
  /// safely and synchronously fetching current values for some dynamic
  /// parameters.
  DeviceContext() : _json = Map<String, dynamic>.from(_prefetchedValues) {
    // This is usually called when an error occurs. Application, including
    // Flutter framework, may be unstable at this point. We still try to get
    // the data, but wrap our attempt in try..catch.
    try {
      _json.addAll(_getDynamicValues());
    } catch (e) {
      // The data will be there since the prefetch() call, but might be stale.
      _json['context_refresh_error'] = e.toString();
    }
  }

  /// Returns a [Map] of values that may change dynamically during the runtime
  /// of the app.
  static Map<String, dynamic> _getDynamicValues() {
    WidgetsFlutterBinding.ensureInitialized();
    final window = WidgetsBinding.instance.window;
    return <String, dynamic>{
      'screen_resolution': '${window.physicalSize.height.toInt()}x'
          '${window.physicalSize.width.toInt()}',
      'orientation': window.physicalSize.width > window.physicalSize.height
          ? 'landscape'
          : 'portrait',
      'screen_density': window.devicePixelRatio,
      'screen_width_pixels': window.physicalSize.width,
      'screen_height_pixels': window.physicalSize.height,
      'timezone': DateTime.now().timeZoneName,
    };
  }

  /// Returns a [Map] of values that usually do not change during the runtime of
  /// the app.
  static Future<Map<String, dynamic>> _getStaticValues() async {
    WidgetsFlutterBinding.ensureInitialized();
    final deviceExtras = <String, dynamic>{};
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceExtras.addAll(<String, dynamic>{
        'device': androidInfo.device,
        'manufacturer': androidInfo.manufacturer,
        'brand': androidInfo.brand,
        'simulator': !androidInfo.isPhysicalDevice,
        'archs': androidInfo.supportedAbis,
        'os': {
          'version': androidInfo.version.release,
          'build': androidInfo.id,
          'name': 'Android',
        },
      });
    }

    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceExtras.addAll(<String, dynamic>{
        'device': iosInfo.model,
        'family': iosInfo.systemName,
        'arch': iosInfo.utsname.machine,
        'version': iosInfo.systemVersion,
      });
      // TODO(ksheremet): Use it in "os" context.
      //buildDeviceExtras['kernel_version'] = iosInfo.utsname.version;
    }

    return deviceExtras;
  }

  static final _prefetchedValues = <String, dynamic>{};

  /// Cache static and dynamic values for later use.
  static Future<void> prefetch() async => _prefetchedValues
    ..addAll(_getDynamicValues())
    ..addAll(await _getStaticValues());

  final Map<String, dynamic> _json;

  /// Get the [Map] representation of this context snapshot, suitable for Sentry
  /// `Event.toJson` method.
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_json);
}

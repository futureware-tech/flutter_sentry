import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';

import '../flutter_sentry.dart';
import 'breadcrumb_tracker.dart';

/// Mapper of [RouteSettings] into Sentry [Breadcrumb].
typedef RouteDataExtractor = Breadcrumb Function(RouteSettings);

/// Default implementation of [RouteDataExtractor] which tracks route name as a
/// message, and tries to converge [RouteSettings.arguments] into breadcrumb
/// data, if it's a map with [String] keys.
Breadcrumb defaultRouteDataExtractor(RouteSettings route) {
  final arguments = route.arguments;
  return Breadcrumb(
    message: route.name,
    timestamp: DateTime.now().toUtc(),
    category: 'navigation',
    data: arguments is Map<String, dynamic>
        ? arguments.map<String, String>(
            (key, dynamic value) => MapEntry(key, value.toString()),
          )
        : arguments == null
            ? null
            : <String, String>{
                'arguments': arguments.toString(),
              },
  );
}

/// A [RouteObserver] which can be used inside [Navigator] to add all navigation
/// events to the Sentry [breadcrumbs], which will be included in all error
/// reports.
///
/// Example usage:
///
/// ```dart
/// MaterialApp(
///   ...
///   navigatorObservers: [
///     FlutterSentryNavigatorObserver(
///       breadcrumbs: FlutterSentry.instance.breadcrumbs,
///     ),
///   ],
/// )
/// ```
class FlutterSentryNavigatorObserver extends RouteObserver<PageRoute> {
  /// Create an instance of [RouteObserver] which will record navigation events
  /// and add to [breadcrumbs] after mapping them using [dataExtractor]. This
  /// object is merely an incapsulation and does not hold any state.
  FlutterSentryNavigatorObserver({
    BreadcrumbTracker breadcrumbs,
    this.dataExtractor = defaultRouteDataExtractor,
  }) : breadcrumbs = breadcrumbs ?? FlutterSentry.instance.breadcrumbs;

  /// Destination for tracking navigation events.
  final BreadcrumbTracker breadcrumbs;

  /// A mapping function to create [Breadcrumb] from [RouteSettings].
  final RouteDataExtractor dataExtractor;

  void _trackScreenView(RouteSettings route) =>
      breadcrumbs.add(dataExtractor(route));

  @override
  void didPush(Route<dynamic> route, Route<dynamic> previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      _trackScreenView(route.settings);
    }
  }

  @override
  void didReplace({Route<dynamic> newRoute, Route<dynamic> oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) {
      _trackScreenView(newRoute.settings);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic> previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute && route is PageRoute) {
      _trackScreenView(previousRoute.settings);
    }
  }
}

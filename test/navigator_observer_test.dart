import 'package:flutter/widgets.dart';
import 'package:flutter_sentry/flutter_sentry.dart';
import 'package:flutter_sentry/src/breadcrumb_tracker.dart';
import 'package:flutter_sentry/src/navigator_observer.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group('NavigatorObserver', () {
    PageRoute route(String name, [Object arguments]) => PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => null,
          settings: RouteSettings(name: name, arguments: arguments),
        );

    tearDown(FlutterSentry.deinitialize);

    test('tracks navigation into breadcrumbs by default', () {
      final t = BreadcrumbTracker();
      final observer = FlutterSentryNavigatorObserver(breadcrumbs: t);
      expect(t.breadcrumbs.length, 0);

      observer.didPush(
        route('/', 123),
        null,
      );
      expect(t.breadcrumbs.length, 1);
      expect(t.breadcrumbs.last.message, '/');
      // A value gets toString() called.
      expect(t.breadcrumbs.last.data['arguments'], '123');

      observer.didRemove(
        route('/'),
        route('/abc'),
      );
      expect(t.breadcrumbs.length, 1);

      observer.didReplace(
        oldRoute: route('/', 123),
        newRoute: route('/sign_in', {'premium': true}),
      );
      expect(t.breadcrumbs.length, 2);
      expect(t.breadcrumbs.last.message, '/sign_in');
      // When value is a Map, it goes through with values stringified.
      expect(t.breadcrumbs.last.data, {'premium': 'true'});

      observer.didPop(
        route('/sign_in', {'premium': true}),
        route('/', 123),
      );
      expect(t.breadcrumbs.length, 3);
      // didPop is a little quirky: the 2nd parameter is the route that was
      // beneath, therefore, it's the one being shown to the user.
      expect(t.breadcrumbs.last.message, '/');
      expect(t.breadcrumbs.last.data['arguments'], '123');

      observer.didPush(
        route('/intro'),
        route('/', 123),
      );
      expect(t.breadcrumbs.length, 4);
      expect(t.breadcrumbs.last.message, '/intro');
      expect(t.breadcrumbs.last.data, null);
    });

    test('ignores non-PageRoute routes', () {
      final t = BreadcrumbTracker();
      FlutterSentryNavigatorObserver(breadcrumbs: t).didPush(
        _MockPopupRoute(),
        null,
      );
      expect(t.breadcrumbs.length, 0);
    });

    test('allows custom route data extractor', () {
      final t = BreadcrumbTracker();
      final historicalTimestamp =
          DateTime.now().subtract(const Duration(days: 1024));
      FlutterSentryNavigatorObserver(
        breadcrumbs: t,
        dataExtractor: (routeSettings) => Breadcrumb(
          message: '-> ${routeSettings.name}',
          timestamp: historicalTimestamp,
        ),
      ).didPush(
        route('/home'),
        null,
      );
      expect(t.breadcrumbs.length, 1);
      expect(t.breadcrumbs.last.message, '-> /home');
      expect(t.breadcrumbs.last.data, null);
      expect(t.breadcrumbs.last.timestamp, historicalTimestamp);
    });

    test('uses FlutterSentry breadcrumbs to track navigation by default', () {
      FlutterSentry.initializeWithClient(_MockSentryClient());
      expect(FlutterSentry.instance.breadcrumbs.breadcrumbs.length, 0);
      FlutterSentryNavigatorObserver().didPush(
        route('/home'),
        null,
      );
      expect(FlutterSentry.instance.breadcrumbs.breadcrumbs.length, 1);
    });
  });
}

class _MockPopupRoute extends Mock implements PopupRoute<void> {}

class _MockSentryClient extends Mock implements SentryClient {}

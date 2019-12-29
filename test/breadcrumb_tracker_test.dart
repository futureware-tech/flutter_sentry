import 'package:flutter_sentry/src/breadcrumb_tracker.dart';
import 'package:test/test.dart';

void main() {
  group('Breadcrumbs', () {
    test('records the breadcrumbs', () {
      final tracker = BreadcrumbTracker();
      expect(tracker.breadcrumbs.length, 0);
      tracker.add(null);
      expect(tracker.breadcrumbs.length, 1);
      tracker.add(null);
      expect(tracker.breadcrumbs.length, 2);
    });

    test('limits the number of breadcrumbs', () {
      final tracker = BreadcrumbTracker(maxElements: 1)..add(null);
      expect(tracker.breadcrumbs.length, 1);
      tracker.add(null);
      expect(tracker.breadcrumbs.length, 1);
    });
  });
}

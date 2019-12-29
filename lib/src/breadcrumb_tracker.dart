import 'dart:collection';

import 'package:sentry/sentry.dart';

/// Keeper of in-memory list of [Breadcrumb] objects, allowing a limit.
class BreadcrumbTracker {
  /// Create a new instance that keeps up to [maxElements] in memory. The value
  /// of [maxElements] must be greater than zero.
  BreadcrumbTracker({this.maxElements = 1024})
      : assert(
            maxElements > 0,
            'The number of maxElements specified ($maxElements) must be '
            'greater than zero.');

  /// Number of [Breadcrumb] elements to keep around before oldest elements will
  /// start being pushed out of the queue. Note that this has very little to do
  /// with how much memory is allocated by this object.
  final int maxElements;

  final _breadcrumbs = ListQueue<Breadcrumb>();

  /// Currently recorded breadcrumbs. The size of this iterable will not exceed
  /// [maxElements].
  Iterable<Breadcrumb> get breadcrumbs => _breadcrumbs;

  /// Add a breadcrumb to the end of the queue, popping oldest elements if
  /// [maxElements] number of elements would be exceeded.
  void add(Breadcrumb value) {
    while (_breadcrumbs.length >= maxElements) {
      // TODO(dotdoom): push out elements with lower severity first.
      _breadcrumbs.removeFirst();
    }
    _breadcrumbs.add(value);
  }
}

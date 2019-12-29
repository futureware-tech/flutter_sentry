import 'package:flutter/material.dart';
import 'package:sentry/sentry.dart';

/// An event to be reported to Sentry.io. It extends sentry Event to make
/// event information look closer to what comes from native platform plugins.
@immutable
class FlutterEvent extends Event {
  /// Creates an event.
  const FlutterEvent({
    String loggerName,
    String serverName,
    String release,
    String environment,
    String message,
    String transaction,
    dynamic exception,
    dynamic stackTrace,
    SeverityLevel level,
    String culprit,
    Map<String, String> tags,
    Map<String, String> extra,
    List<String> fingerprint,
    User userContext,
    List<Breadcrumb> breadcrumbs,
    this.deviceContext,
  }) : super(
          loggerName: loggerName,
          serverName: serverName,
          release: release,
          environment: environment,
          message: message,
          transaction: transaction,
          exception: exception,
          stackTrace: stackTrace,
          level: level,
          culprit: culprit,
          tags: tags,
          extra: extra,
          fingerprint: fingerprint,
          userContext: userContext,
          breadcrumbs: breadcrumbs,
        );

  /// Key/value pairs that describe the device where this event occured.
  /// https://docs.sentry.io/development/sdk-dev/event-payloads/contexts/
  final Map<String, dynamic> deviceContext;

  @override
  Map<String, dynamic> toJson({
    // TODO(ksheremet): Event.toJson uses StackFrameFilter as a parameter, which
    // is not exported from sentry plugin. StackFrameFilter is also used in
    // sentryClient.capture. Consider sending PR to sentry to export this API.
    List<Map<String, dynamic>> Function(List<Map<String, dynamic>>)
        stackFrameFilter,
    String origin,
  }) {
    final json = super.toJson(
      stackFrameFilter: stackFrameFilter,
      origin: origin,
    );
    // https://docs.sentry.io/development/sdk-dev/event-payloads/contexts/
    json['contexts'] = {
      'device': deviceContext,
    };

    return json;
  }
}

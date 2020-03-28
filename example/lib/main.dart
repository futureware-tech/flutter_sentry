import 'package:flutter/material.dart';
import 'package:flutter_sentry/flutter_sentry.dart';

void main() => FlutterSentry.wrap(
      () {
        runApp(MaterialApp(
          navigatorObservers: [
            FlutterSentryNavigatorObserver(
              breadcrumbs: FlutterSentry.instance.breadcrumbs,
            ),
          ],
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Flutter Sentry plugin example app'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const RaisedButton(
                    onPressed: FlutterSentry.nativeCrash,
                    child: Text('Cause a native crash'),
                  ),
                  RaisedButton(
                    onPressed: () {
                      debugPrint('Throwing an uncaught exception');
                      throw Exception('Uncaught exception');
                    },
                    child: const Text('Throw uncaught exception'),
                  ),
                  RaisedButton(
                    onPressed: () => FlutterSentry.instance.captureException(
                      exception: Exception('Event'),
                    ),
                    child: const Text('Report an event to Sentry.io'),
                  ),
                ],
              ),
            ),
          ),
        ));
      },
      dsn: 'https://420a0b0766e9450fbd3a456346c6eed2@sentry.io/1867468',
    );

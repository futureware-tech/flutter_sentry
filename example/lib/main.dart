import 'package:flutter/material.dart';
import 'package:flutter_sentry/flutter_sentry.dart';
import 'package:sentry/sentry.dart';

void main() => FlutterSentry.wrap(
      () {
        runApp(const MyApp());
      },
      dsn: 'https://420a0b0766e9450fbd3a456346c6eed2@sentry.io/1867468',
    );

/// Main application widget class.
@immutable
class MyApp extends StatelessWidget {
  /// New instance of MyApp widget.
  const MyApp({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorObservers: [
          FlutterSentryNavigatorObserver(),
        ],
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Flutter Sentry plugin example app'),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: () {
                      FlutterSentry.instance.userContext = const User(
                        id: '0123456789',
                        email: 'test@example.com',
                        extras: <String, dynamic>{
                          // This can be anything you like.
                          'purchased': true,
                          'signInMethod': 'Anonymous',
                          'currentConfig': {
                            'minApplicationVersion': '2.5',
                            'sharingFeatureEnabled': false,
                          },
                        },
                      );
                    },
                    child: const Text('Sign in (initialize User context)'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      FlutterSentry.instance.userContext = null;
                    },
                    child: const Text('Sign out (clear User context)'),
                  ),
                  const Divider(),
                  const ElevatedButton(
                    onPressed: FlutterSentry.nativeCrash,
                    child: Text('Cause a native crash (reported on restart)'),
                  ),
                  ElevatedButton(
                    onPressed: () => FlutterSentry.instance.captureException(
                      exception: Exception('Event'),
                      extra: <String, dynamic>{
                        'extra Data': 'hello, world!',
                      },
                    ),
                    child: const Text('Report an event to Sentry.io'),
                  ),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('The following works in release mode only:'),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      debugPrint('Throwing an uncaught exception');
                      throw Exception('Uncaught exception');
                    },
                    child: const Text('Throw uncaught exception'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Will fail because Scaffold is below current context:
                      // https://link.medium.com/TyUYuWoer5.
                      Scaffold.of(context);
                    },
                    child: const Text('Cause and report a FlutterError'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

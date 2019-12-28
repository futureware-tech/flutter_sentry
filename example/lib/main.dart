import 'package:flutter/material.dart';
import 'package:flutter_sentry/flutter_sentry.dart';

void main() => FlutterSentry.wrap(
      () async => runApp(MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Flutter Sentry plugin example app'),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                RaisedButton(
                  child: Text('Cause a native crash'),
                  onPressed: FlutterSentry.nativeCrash,
                ),
                RaisedButton(
                  child: Text('Throw uncaught exception'),
                  onPressed: () => throw Exception('Uncaught exception'),
                ),
              ],
            ),
          ),
        ),
      )),
      dsn: 'https://420a0b0766e9450fbd3a456346c6eed2@sentry.io/1867468',
    );

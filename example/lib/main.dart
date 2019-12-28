import 'package:flutter/material.dart';

import 'package:flutter_sentry/flutter_sentry.dart';

void main() => runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Sentry plugin example app'),
        ),
        body: Center(
          child: RaisedButton(
            child: Text('Cause a native crash'),
            onPressed: FlutterSentry.nativeCrash,
          ),
        ),
      ),
    )
);

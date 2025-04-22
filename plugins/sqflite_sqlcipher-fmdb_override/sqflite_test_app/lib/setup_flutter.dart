import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: implementation_imports
import 'package:sqflite_common_ffi/src/mixin/handler_mixin.dart';

/// Use `sqflite_ffi` as the mock implementation for unit test or regular
///
/// application using `sqflite`
@visibleForTesting
void sqfliteFfiInitAsMockMethodCallHandler() {
  const channel = MethodChannel('com.tekartik.sqflite');

  channel.setMethodCallHandler((MethodCall methodCall) async {
    try {
      return await FfiMethodCall(methodCall.method, methodCall.arguments)
          .handleInIsolate();
    } on SqfliteFfiException catch (e) {
      // Re-convert to a Platform exception to make flutter services happy
      throw PlatformException(
          code: e.code, message: e.message, details: e.details);
    }
  });
}

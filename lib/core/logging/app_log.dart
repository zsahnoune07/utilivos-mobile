import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Debug-only structured logging; no output in release builds.
/// Prefer this over raw [dart:developer] calls in feature code.
void appLog(
  String name,
  String message, {
  Object? error,
  StackTrace? stackTrace,
}) {
  if (kReleaseMode) {
    return;
  }
  developer.log(
    message,
    name: name,
    error: error,
    stackTrace: stackTrace,
  );
}

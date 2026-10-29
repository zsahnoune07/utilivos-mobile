import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

// #region agent log
const _kDebugLogPath = '/media/Shared/Projects/Utilivo/.cursor/debug-f46089.log';
const _kIngestUrl =
    'http://127.0.0.1:7441/ingest/1ac0e47b-81a6-40dd-89d2-c71eaa8c0055';
const _kSessionId = 'f46089';

void debugSessionIngest({
  required String location,
  required String message,
  required String hypothesisId,
  Map<String, String>? data,
  String? runId,
}) {
  if (kReleaseMode) {
    return;
  }
  unawaited(_writeLine(
    {
      'sessionId': _kSessionId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'location': location,
      'message': message,
      'hypothesisId': hypothesisId,
      if (runId != null) 'runId': runId,
      'data': data,
    },
  ));
}

Future<void> _writeLine(Map<String, Object?> obj) async {
  final line = jsonEncode(obj);
  try {
    final f = File(_kDebugLogPath);
    await f.writeAsString(
      '$line\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (_) {
    HttpClient? client;
    try {
      client = HttpClient();
      final req = await client.postUrl(Uri.parse(_kIngestUrl));
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('X-Debug-Session-Id', _kSessionId);
      req.add(utf8.encode(jsonEncode(obj)));
      await req.close();
    } catch (_) {
      // Host unreachable (e.g. device without adb reverse) — no sink.
    } finally {
      client?.close(force: true);
    }
  }
}
// #endregion

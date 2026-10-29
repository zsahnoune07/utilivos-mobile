import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// Dev-only bundle verification diagnostics. Not used in release/profile builds.
// Tag is stable for log filtering and to avoid shipping dev copy in prod trees.
// -----------------------------------------------------------------------------

/// Search / analytics tag: dev-only bundle error UI. Do not use in user-facing
/// production strings (release builds never show this layer).
const String kUtilivosDevBundleErrorTag = 'utilivos.dev.bundle_error_v1';

/// When true, [ToolBundleFormatException] / [ToolBundleIntegrityException] may
/// carry [devOnlyDetails] and the app may show a full diagnostic dialog.
@pragma('vm:prefer-inline')
bool get kUtilivosBundleDevDiagnosticsEnabled => kDebugMode;

void showUtilivosBundleErrorDevDialogIfEnabled(
  BuildContext context, {
  required String title,
  required String source,
  required String summaryMessage,
  Map<String, String>? devOnlyDetails,
}) {
  if (!kUtilivosBundleDevDiagnosticsEnabled) {
    return;
  }
  if (devOnlyDetails == null || devOnlyDetails.isEmpty) {
    return;
  }
  final buffer = StringBuffer()
    ..writeln('[$kUtilivosDevBundleErrorTag]')
    ..writeln('source: $source')
    ..writeln('message: $summaryMessage')
    ..writeln();
  final keys = devOnlyDetails.keys.toList()..sort();
  for (final k in keys) {
    buffer.writeln('$k:');
    buffer.writeln(devOnlyDetails[k]);
    buffer.writeln();
  }
  final body = buffer.toString();
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) {
      return AlertDialog(
        title: Text(
          'Dev: $title',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              body,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/app_localizations.dart';
import '../tool_manifest/tool_manifest_models.dart';
import 'system_permission_port.dart';

/// Outcome of [ToolPermissionCoordinator.ensureSystemPermissions].
enum ToolPermissionFlowResult {
  granted,
  cancelled,
  denied,
  permanentlyDenied,
}

/// Host-only orchestration for manifest `permissions` that map to OS prompts.
///
/// Requests are **sequential** (one rationale dialog → one OS request at a time).
class ToolPermissionCoordinator {
  ToolPermissionCoordinator({SystemPermissionPort? port})
    : _port = port ?? const PermissionHandlerSystemPort();

  final SystemPermissionPort _port;

  /// Ensures every declared **system** permission (camera, microphone, location) is granted.
  Future<ToolPermissionFlowResult> ensureSystemPermissions({
    required BuildContext context,
    required ParsedToolManifest manifest,
    required AppLocalizations l10n,
  }) async {
    final seen = <String>{};
    final ordered = <ToolManifestPermission>[];
    for (final p in manifest.systemPermissions) {
      final k = p.type.trim().toLowerCase();
      if (k.isEmpty || seen.contains(k)) {
        continue;
      }
      seen.add(k);
      ordered.add(p);
    }

    for (final decl in ordered) {
      final permission = permissionForManifestType(decl.type);
      if (permission == null) {
        continue;
      }

      var status = await _port.status(permission);
      if (status.isGranted) {
        continue;
      }

      if (!context.mounted) {
        return ToolPermissionFlowResult.cancelled;
      }

      if (status.isPermanentlyDenied) {
        return ToolPermissionFlowResult.permanentlyDenied;
      }

      final message =
          decl.rationale?.trim().isNotEmpty == true
          ? decl.rationale!.trim()
          : l10n.runtimePermissionDefaultRationale;

      final goAhead = await _showRationaleDialog(
        context: context,
        message: message,
        l10n: l10n,
      );
      if (goAhead != true) {
        return ToolPermissionFlowResult.cancelled;
      }

      status = await _port.request(permission);
      if (status.isGranted) {
        continue;
      }
      if (status.isPermanentlyDenied) {
        return ToolPermissionFlowResult.permanentlyDenied;
      }
      return ToolPermissionFlowResult.denied;
    }

    return ToolPermissionFlowResult.granted;
  }

  Future<bool?> _showRationaleDialog({
    required BuildContext context,
    required String message,
    required AppLocalizations l10n,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(l10n.runtimePermissionRequiredTitle),
          content: SingleChildScrollView(child: Text(message)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.runtimePermissionContinueCta),
            ),
          ],
        );
      },
    );
  }
}

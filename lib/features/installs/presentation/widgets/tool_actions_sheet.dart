import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_buttons.dart';
import '../../application/installed_tools_controller.dart';
import '../../data/models/install_models.dart';
import '../../data/models/installs_organization_models.dart';
import 'folder_ui_catalog.dart';

enum _ToolActionsSheetStep { actions, move }

class ToolActionsSheet extends StatefulWidget {
  const ToolActionsSheet({
    required this.install,
    required this.controller,
    required this.onLaunch,
    required this.onDelete,
    required this.onTogglePin,
    required this.folders,
    required this.onAssignFolder,
    required this.onRemoveFromFolder,
    this.onCreateFolderInFlow,
    this.onUpdate,
    this.folderContextOnly = false,
    super.key,
  });

  final DeviceInstallRecord install;
  final InstalledToolsController controller;
  final VoidCallback onLaunch;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;
  final List<ToolFolder> folders;
  final ValueChanged<String> onAssignFolder;
  final VoidCallback onRemoveFromFolder;
  final Future<String?> Function()? onCreateFolderInFlow;
  final VoidCallback? onUpdate;
  final bool folderContextOnly;

  static String _formatTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  State<ToolActionsSheet> createState() => _ToolActionsSheetState();
}

class _ToolActionsSheetState extends State<ToolActionsSheet> {
  static const ValueKey<String> _actionsStepKey = ValueKey<String>(
    'tool-actions-step-main',
  );
  static const ValueKey<String> _moveStepKey = ValueKey<String>(
    'tool-actions-step-move',
  );
  _ToolActionsSheetStep _step = _ToolActionsSheetStep.actions;
  bool _isForwardTransition = true;

  void _openMoveStep() {
    setState(() {
      _isForwardTransition = true;
      _step = _ToolActionsSheetStep.move;
    });
  }

  void _backToActionsStep() {
    if (_step == _ToolActionsSheetStep.actions) {
      return;
    }
    setState(() {
      _isForwardTransition = false;
      _step = _ToolActionsSheetStep.actions;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = widget.install.updateAvailable
        ? 'Update available: ${widget.install.latestAvailableVersion ?? 'latest'}'
        : 'Up to date';
    final canPin =
        widget.install.pinned ||
        widget.controller.pinnedCount < InstalledToolsController.maxPinnedTools;

    return PopScope(
      canPop: _step == _ToolActionsSheetStep.actions,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _backToActionsStep();
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          layoutBuilder:
              (Widget? currentChild, List<Widget> previousChildren) =>
                  ClipRect(child: Stack(children: <Widget>[?currentChild])),
          transitionBuilder: (Widget child, Animation<double> animation) {
            final activeKey = _step == _ToolActionsSheetStep.actions
                ? _actionsStepKey
                : _moveStepKey;
            final isActiveChild = child.key == activeKey;
            if (!isActiveChild) {
              return const SizedBox.shrink();
            }
            final beginOffset = _isForwardTransition
                ? const Offset(0.2, 0)
                : const Offset(-0.2, 0);
            return SlideTransition(
              position: Tween<Offset>(
                begin: beginOffset,
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: _step == _ToolActionsSheetStep.actions
              ? _buildActionsStep(context, colorScheme, status, canPin)
              : _buildMoveStep(context),
        ),
      ),
    );
  }

  Widget _buildActionsStep(
    BuildContext context,
    ColorScheme colorScheme,
    String status,
    bool canPin,
  ) {
    return SingleChildScrollView(
      key: _actionsStepKey,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            widget.install.displayName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: 'Launch tool',
            onPressed: widget.onLaunch,
            expand: true,
          ),
          if (widget.install.updateAvailable &&
              widget.onUpdate != null) ...<Widget>[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: widget.onUpdate,
              icon: const Icon(Icons.system_update_alt, size: 20),
              label: Text(
                'Update to ${widget.install.latestAvailableVersion ?? "latest"}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: canPin ? widget.onTogglePin : null,
            icon: Icon(
              widget.install.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              size: 20,
            ),
            label: Text(
              widget.install.pinned ? 'Unpin tool' : 'Pin tool',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          if (widget.folders.isNotEmpty || widget.onCreateFolderInFlow != null)
            OutlinedButton.icon(
              onPressed: _openMoveStep,
              icon: const Icon(Icons.folder_open_outlined, size: 20),
              label: const Text(
                'Move to folder',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          if (widget.install.folderId != null || widget.folderContextOnly)
            OutlinedButton.icon(
              onPressed: widget.onRemoveFromFolder,
              icon: const Icon(Icons.folder_off_outlined, size: 20),
              label: const Text(
                'Remove from folder',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                barrierColor: Colors.transparent,
                builder: (BuildContext ctx) => AlertDialog(
                  title: const Text('Delete tool?'),
                  content: Text(
                    'Remove "${widget.install.displayName}" from this device? You can install it again from the Tool Library.',
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                widget.onDelete();
              }
            },
            icon: Icon(
              Icons.delete_outline,
              size: 20,
              color: colorScheme.error,
            ),
            label: Text(
              'Delete tool',
              style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error),
            ),
          ),
          const SizedBox(height: 24),
          if (widget.install.categoryName != null)
            _DetailRow(
              label: 'Category',
              value: widget.install.categoryName!.trim(),
            ),
          _DetailRow(
            label: 'Installed version',
            value: widget.install.installedVersion ?? 'unknown',
          ),
          _DetailRow(label: 'Status', value: status),
          _DetailRow(
            label: 'Installed at',
            value: ToolActionsSheet._formatTime(widget.install.installedAt),
          ),
        ],
      ),
    );
  }

  Widget _buildMoveStep(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      key: _moveStepKey,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 16, 4),
          child: Row(
            children: <Widget>[
              IconButton(
                tooltip: 'Back',
                onPressed: _backToActionsStep,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Text(
                'Move to folder',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              if (widget.onCreateFolderInFlow != null)
                ListTile(
                  leading: Icon(
                    Icons.create_new_folder_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('Create new folder'),
                  onTap: () async {
                    final createdFolderId =
                        await widget.onCreateFolderInFlow!();
                    if (createdFolderId != null && createdFolderId.isNotEmpty) {
                      widget.onAssignFolder(createdFolderId);
                    }
                  },
                ),
              ...widget.folders.map(
                (folder) => ListTile(
                  leading: Icon(FolderUiCatalog.iconFor(folder.iconKey)),
                  title: Text(folder.name),
                  onTap: () => widget.onAssignFolder(folder.id),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

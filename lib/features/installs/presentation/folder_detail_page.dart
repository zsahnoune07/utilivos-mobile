import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_routes.dart';
import '../application/installed_tools_controller.dart';
import '../data/models/install_models.dart';
import '../data/models/installs_organization_models.dart';
import 'widgets/folder_editor_modal.dart';
import 'widgets/folder_ui_catalog.dart';
import 'widgets/installed_tool_card.dart';
import 'widgets/tool_actions_sheet.dart';

class FolderDetailPage extends StatelessWidget {
  const FolderDetailPage({
    required this.folderId,
    required this.controller,
    super.key,
  });

  final String folderId;
  final InstalledToolsController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final folder = controller.folderById(folderId);
        if (folder == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Folder')),
            body: Center(
              child: TextButton(
                onPressed: () => context.pop(),
                child: const Text('Folder not found. Go back'),
              ),
            ),
          );
        }
        final tools = controller.toolsForFolder(folder.id);
        final colorScheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final folderColor = FolderUiCatalog.colorFor(folder.colorKey);
        final folderTint = folderColor.withValues(alpha: isDark ? 0.24 : 0.15);
        final headerColor = Color.alphaBlend(folderTint, colorScheme.surface);
        final onHeaderColor =
            ThemeData.estimateBrightnessForColor(headerColor) == Brightness.dark
            ? Colors.white
            : Colors.black;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: headerColor,
            foregroundColor: onHeaderColor,
            surfaceTintColor: Colors.transparent,
            iconTheme: IconThemeData(color: onHeaderColor),
            title: Text(
              folder.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 24,
                letterSpacing: 0.2,
              ),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Edit folder',
                onPressed: () => _showFolderEditor(context, folder: folder),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete folder',
                onPressed: () => _confirmDeleteFolder(context, folder),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: tools.isEmpty
              ? const Center(
                  child: Text(
                    'No tools in this folder yet.',
                    textAlign: TextAlign.center,
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.86,
                  ),
                  itemCount: tools.length,
                  itemBuilder: (context, index) {
                    final tool = tools[index];
                    return RepaintBoundary(
                      child: InstalledToolCard(
                        install: tool,
                        iconPath: tool.iconPath,
                        dominantColorHex: tool.cardAccentColor,
                        onTap: () async {
                          await controller.markToolLaunched(tool.pluginSlug);
                          if (!context.mounted) {
                            return;
                          }
                          context.push(
                            AppRoutes.pluginRuntime(
                              tool.pluginSlug,
                              toolName: tool.displayName,
                            ),
                          );
                        },
                        onLongPress: () =>
                            _showToolDetailsModal(context, install: tool),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _confirmDeleteFolder(
    BuildContext context,
    ToolFolder folder,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete folder?'),
          content: Text(
            'Delete "${folder.name}"? Tools stay installed and become unassigned.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await controller.deleteFolder(folder.id);
    if (!context.mounted) {
      return;
    }
    context.pop();
  }

  Future<void> _showFolderEditor(
    BuildContext context, {
    required ToolFolder folder,
  }) async {
    final result = await showFolderEditorModal(
      context,
      folder: folder,
      validateFolderName: (name) =>
          controller.hasFolderWithName(name, excludeFolderId: folder.id)
              ? 'A folder with this name already exists.'
              : null,
    );
    if (result == null) {
      return;
    }
    if (result.type == FolderEditorResultType.delete) {
      await controller.deleteFolder(folder.id);
      if (context.mounted) {
        context.pop();
      }
      return;
    }
    await controller.updateFolder(
      folderId: folder.id,
      name: result.name,
      iconKey: result.iconKey,
      colorKey: result.colorKey,
    );
  }

  void _showToolDetailsModal(
    BuildContext context, {
    required DeviceInstallRecord install,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return ToolActionsSheet(
          install: install,
          controller: controller,
          folderContextOnly: false,
          onLaunch: () {
            Navigator.of(sheetContext).pop();
            controller.markToolLaunched(install.pluginSlug);
            context.push(
              AppRoutes.pluginRuntime(
                install.pluginSlug,
                toolName: install.displayName,
              ),
            );
          },
          onUpdate: null,
          onDelete: () async {
            await controller.removeInstall(install);
            if (sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
            }
          },
          onTogglePin: () async {
            await controller.togglePin(install);
            if (sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
            }
          },
          folders: controller.folders,
          onAssignFolder: (folderId) async {
            await controller.assignToolToFolder(
              pluginSlug: install.pluginSlug,
              folderId: folderId,
            );
            if (sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
            }
          },
          onCreateFolderInFlow: () async {
            final result = await showFolderEditorModal(
              context,
              barrierColor: Colors.transparent,
              validateFolderName: (name) =>
                  controller.hasFolderWithName(name)
                      ? 'A folder with this name already exists.'
                      : null,
            );
            if (result == null || result.type != FolderEditorResultType.save) {
              return null;
            }
            final createdFolder = await controller.createFolder(
              name: result.name,
              iconKey: result.iconKey,
              colorKey: result.colorKey,
            );
            return createdFolder.id;
          },
          onRemoveFromFolder: () async {
            await controller.removeToolFromFolder(
              pluginSlug: install.pluginSlug,
            );
            if (sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
            }
          },
        );
      },
    );
  }
}

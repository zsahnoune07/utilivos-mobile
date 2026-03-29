import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/installs_organization_models.dart';
import 'folder_ui_catalog.dart';

enum FolderEditorResultType { save, delete }

class FolderEditorResult {
  const FolderEditorResult({
    required this.type,
    required this.name,
    required this.iconKey,
    required this.colorKey,
  });

  final FolderEditorResultType type;
  final String name;
  final String iconKey;
  final String colorKey;
}

Future<FolderEditorResult?> showFolderEditorModal(
  BuildContext context, {
  ToolFolder? folder,
  Color? barrierColor,
  String? Function(String name)? validateFolderName,
}) async {
  final isEdit = folder != null;
  final originalName = folder?.name.trim() ?? '';
  final nameController = TextEditingController(text: folder?.name ?? '');
  final nameFocusNode = FocusNode();
  final formKey = GlobalKey<FormState>();
  var selectedIcon = folder?.iconKey ?? FolderUiCatalog.iconKeys.first;
  var selectedColor = folder?.colorKey ?? FolderUiCatalog.colorKeys.first;
  if (!FolderUiCatalog.iconKeys.contains(selectedIcon)) {
    selectedIcon = FolderUiCatalog.iconKeys.first;
  }
  if (!FolderUiCatalog.colorKeys.contains(selectedColor)) {
    selectedColor = FolderUiCatalog.colorKeys.first;
  }

  final result = await showModalBottomSheet<FolderEditorResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    barrierColor: barrierColor,
    builder: (modalContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return SafeArea(
            top: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextFormField(
                        controller: nameController,
                        focusNode: nameFocusNode,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        maxLength: 16,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        inputFormatters: <TextInputFormatter>[
                          LengthLimitingTextInputFormatter(16),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Folder name',
                        ),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Folder name is required.';
                          }
                          final isLegacyUnchangedLongName =
                              isEdit &&
                              originalName.length > 16 &&
                              trimmed == originalName;
                          if (trimmed.length > 16 &&
                              !isLegacyUnchangedLongName) {
                            return 'Folder name must be 16 characters or less.';
                          }
                          final duplicateError =
                              validateFolderName?.call(trimmed);
                          if (duplicateError != null &&
                              duplicateError.isNotEmpty) {
                            return duplicateError;
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) {
                          if (formKey.currentState?.validate() != true) {
                            return;
                          }
                          Navigator.of(context).pop(
                            FolderEditorResult(
                              type: FolderEditorResultType.save,
                              name: nameController.text.trim(),
                              iconKey: selectedIcon,
                              colorKey: selectedColor,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Color',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 54,
                        child: ListView.separated(
                          key: const Key('folder-color-carousel'),
                          scrollDirection: Axis.horizontal,
                          itemCount: FolderUiCatalog.colorKeys.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final key = FolderUiCatalog.colorKeys[index];
                            final color = FolderUiCatalog.colorFor(key);
                            final isSelected = key == selectedColor;
                            return GestureDetector(
                              onTap: () =>
                                  setModalState(() => selectedColor = key),
                              child: AnimatedContainer(
                                key: Key('folder-color-$key'),
                                duration: const Duration(milliseconds: 120),
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurface
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check_rounded,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surface,
                                        size: 24,
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Icon',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              crossAxisSpacing: 5,
                              mainAxisSpacing: 5,
                              childAspectRatio: 1,
                            ),
                        itemCount: FolderUiCatalog.iconKeys.length,
                        itemBuilder: (context, index) {
                          final key = FolderUiCatalog.iconKeys[index];
                          final selected = key == selectedIcon;
                          final color = FolderUiCatalog.colorFor(selectedColor);
                          return InkWell(
                            key: Key('folder-icon-$key'),
                            borderRadius: BorderRadius.circular(10),
                            onTap: () =>
                                setModalState(() => selectedIcon = key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? color
                                      : Theme.of(context)
                                            .colorScheme
                                            .outlineVariant
                                            .withValues(alpha: 0.6),
                                  width: selected ? 2 : 1,
                                ),
                                color: selected
                                    ? color.withValues(alpha: 0.16)
                                    : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.25),
                              ),
                              child: Icon(
                                FolderUiCatalog.iconFor(key),
                                size: 24,
                                color: selected
                                    ? color
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            nameFocusNode.unfocus();
                            if (formKey.currentState?.validate() != true) {
                              return;
                            }
                            Navigator.of(context).pop(
                              FolderEditorResult(
                                type: FolderEditorResultType.save,
                                name: nameController.text.trim(),
                                iconKey: selectedIcon,
                                colorKey: selectedColor,
                              ),
                            );
                          },
                          child: Text(isEdit ? 'Save folder' : 'Create folder'),
                        ),
                      ),
                      if (isEdit) ...<Widget>[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop(
                                FolderEditorResult(
                                  type: FolderEditorResultType.delete,
                                  name: nameController.text.trim(),
                                  iconKey: selectedIcon,
                                  colorKey: selectedColor,
                                ),
                              );
                            },
                            child: const Text('Delete folder'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
  return result;
}

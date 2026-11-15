import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/format.dart';

class FileItem {
  final FileSystemEntity entity;
  final String name;
  final String size;
  final bool isDirectory;
  final String path;
  final DateTime? modifiedTime;

  FileItem({
    required this.entity,
    required this.name,
    required this.size,
    required this.isDirectory,
    required this.path,
    this.modifiedTime,
  });
}

class SettingsFilesScreen extends BaseStateFulWidget {
  static const String routeName = '/settings/files';

  @override
  _SettingsFilesScreenState createState() => _SettingsFilesScreenState();
}

class _SettingsFilesScreenState extends BaseStateFulWidgetState<SettingsFilesScreen> {
  Directory _currentDirectory = Settings.applicationRootDirectory;
  List<FileItem> _files = [];
  String? _totalSize;
  bool _isLoading = false;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<FileItem> files = [];
      double totalSize = 0;

      if (_currentDirectory.existsSync()) {
        List<FileSystemEntity> entities = _currentDirectory.listSync();
        entities.sort((a, b) {
          bool aIsDir = a is Directory;
          bool bIsDir = b is Directory;
          if (aIsDir && !bIsDir) return -1;
          if (!aIsDir && bIsDir) return 1;
          return a.path.toLowerCase().compareTo(b.path.toLowerCase());
        });

        for (FileSystemEntity entity in entities) {
          String name = entity.path.split('/').last;
          double size = await _getSize(entity);
          totalSize += size;
          String sizeStr = Format.flowSize(size, unitArr: ['B', 'KB', 'MB', 'GB']);
          bool isDirectory = entity is Directory;
          
          // Get modified time
          DateTime? modifiedTime;
          try {
            if (entity is File) {
              modifiedTime = await entity.lastModified();
            } else if (entity is Directory) {
              var stat = await entity.stat();
              modifiedTime = stat.modified;
            }
          } catch (e) {
            // Ignore errors getting modified time
          }

          files.add(FileItem(
            entity: entity,
            name: name,
            size: sizeStr,
            isDirectory: isDirectory,
            path: entity.path,
            modifiedTime: modifiedTime,
          ));
        }
      }

      setState(() {
        _files = files;
        _totalSize = Format.flowSize(totalSize, unitArr: ['B', 'KB', 'MB', 'GB']);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Toast.show(Settings.locale((s) => s.error_loading_files(e.toString()), ctx: context));
    }
  }

  Future<double> _getSize(FileSystemEntity entity) async {
    try {
      if (entity is File) {
        return (await entity.length()).toDouble();
      } else if (entity is Directory) {
        // For directories, calculate size recursively but with a limit to avoid performance issues
        double total = 0;
        try {
          await for (FileSystemEntity child in entity.list()) {
            total += await _getSize(child);
          }
        } catch (e) {
          // Ignore permission errors
        }
        return total;
      }
    } catch (e) {
      // Ignore errors
    }
    return 0;
  }

  Future<void> _deleteFile(FileItem item) async {
    await ModalDialog.of(Settings.appContext).confirm(
      titleWidget: Label(
        Settings.locale((s) => s.tips, ctx: context),
        type: LabelType.h3,
        softWrap: true,
      ),
      contentWidget: Label(
        Settings.locale((s) => s.delete_file_confirm_title(item.name), ctx: context),
        type: LabelType.bodyRegular,
        softWrap: true,
      ),
      agree: Button(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Asset.iconSvg(
                'trash',
                color: application.theme.fontLightColor,
                width: 24,
              ),
            ),
            Label(
              Settings.locale((s) => s.delete, ctx: context),
              type: LabelType.h3,
              color: application.theme.fontLightColor,
            )
          ],
        ),
        backgroundColor: application.theme.strongColor,
        width: double.infinity,
        onPressed: () async {
          if (Navigator.of(context).canPop()) Navigator.pop(context);
          Loading.show();
          try {
            if (item.entity.existsSync()) {
              if (item.isDirectory) {
                await (item.entity as Directory).delete(recursive: true);
              } else {
                await (item.entity as File).delete();
              }
              await _loadFiles();
              Toast.show(Settings.locale((s) => s.success, ctx: context));
            }
          } catch (e) {
            Toast.show(Settings.locale((s) => s.error_deleting_file(e.toString()), ctx: context));
          } finally {
            Loading.dismiss();
          }
        },
      ),
      reject: Button(
        width: double.infinity,
        text: Settings.locale((s) => s.cancel, ctx: context),
        fontColor: application.theme.fontColor2,
        backgroundColor: application.theme.backgroundLightColor,
        onPressed: () {
          if (Navigator.of(context).canPop()) Navigator.pop(context);
        },
      ),
    );
  }

  void _navigateToDirectory(FileItem item) {
    if (item.isDirectory) {
      setState(() {
        _currentDirectory = item.entity as Directory;
      });
      _loadFiles();
    }
  }

  void _navigateUp() {
    if (_currentDirectory.path != Settings.applicationRootDirectory.path) {
      setState(() {
        _currentDirectory = _currentDirectory.parent;
      });
      _loadFiles();
    }
  }

  String _formatModifiedTime(DateTime time) {
    try {
      var localizations = Localizations.localeOf(context).toString();
      return DateFormat('yyyy-MM-dd HH:mm:ss', localizations).format(time);
    } catch (e) {
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(time);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.headBarColor2,
      header: Header(
        title: Settings.locale((s) => s.file_manager, ctx: context),
        backgroundColor: application.theme.headBarColor2,
      ),
      body: Column(
        children: <Widget>[
          // Path and total size
          Container(
            padding: const EdgeInsets.all(16),
            color: application.theme.backgroundLightColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (_currentDirectory.path != Settings.applicationRootDirectory.path)
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: application.theme.fontColor1),
                        onPressed: _navigateUp,
                      ),
                    Expanded(
                      child: Label(
                        _currentDirectory.path,
                        type: LabelType.bodySmall,
                        color: application.theme.fontColor2,
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
                if (_totalSize != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Label(
                      '${Settings.locale((s) => s.total, ctx: context)}: $_totalSize',
                      type: LabelType.bodyRegular,
                      color: application.theme.fontColor1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          // File list
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: application.theme.primaryColor,
                    ),
                  )
                : _files.isEmpty
                    ? Center(
                        child: Label(
                          Settings.locale((s) => s.no_files_found, ctx: context),
                          type: LabelType.bodyRegular,
                          color: application.theme.fontColor2,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _files.length,
                        itemBuilder: (context, index) {
                          FileItem item = _files[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: application.theme.backgroundLightColor,
                              border: Border(
                                bottom: BorderSide(
                                  color: application.theme.dividerColor,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(
                                item.isDirectory ? Icons.folder : Icons.insert_drive_file,
                                color: item.isDirectory
                                    ? application.theme.primaryColor
                                    : application.theme.fontColor2,
                              ),
                              title: Label(
                                item.name,
                                type: LabelType.bodyRegular,
                                color: application.theme.fontColor1,
                                fontWeight: FontWeight.bold,
                                softWrap: true,
                                maxLines: null,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Label(
                                    item.size,
                                    type: LabelType.bodySmall,
                                    color: application.theme.fontColor2,
                                  ),
                                  if (item.modifiedTime != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Label(
                                        _formatModifiedTime(item.modifiedTime!),
                                        type: LabelType.bodySmall,
                                        color: application.theme.fontColor2,
                                      ),
                                    ),
                                ],
                              ),
                              isThreeLine: item.modifiedTime != null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  if (item.isDirectory)
                                    IconButton(
                                      icon: Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: application.theme.fontColor2,
                                      ),
                                      onPressed: () => _navigateToDirectory(item),
                                    ),
                                  IconButton(
                                    icon: Asset.iconSvg(
                                      'trash',
                                      width: 20,
                                      color: application.theme.strongColor,
                                    ),
                                    onPressed: () => _deleteFile(item),
                                  ),
                                ],
                              ),
                              onTap: item.isDirectory ? () => _navigateToDirectory(item) : null,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

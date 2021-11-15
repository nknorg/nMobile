import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';

class PhotoScreen extends BaseStateFulWidget {
  static final String routeName = "/photo";
  static final String argFilePath = "file_path";
  static final String argNetUrl = "net_url";

  static Future go(BuildContext context, {String? filePath, String? netUrl}) {
    if ((filePath == null || filePath.isEmpty) && (netUrl == null || netUrl.isEmpty)) return Future.value(null);
    return Navigator.pushNamed(context, routeName, arguments: {
      argFilePath: filePath,
      argNetUrl: netUrl,
    });
  }

  final Map<String, dynamic>? arguments;

  PhotoScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _PhotoScreenState createState() => _PhotoScreenState();
}

class _PhotoScreenState extends BaseStateFulWidgetState<PhotoScreen> with SingleTickerProviderStateMixin {
  static const int TYPE_FILE = 1;
  static const int TYPE_NET = 2;

  int? _contentType;
  String? _content;

  @override
  void onRefreshArguments() {
    String? filePath = widget.arguments![PhotoScreen.argFilePath];
    String? netUrl = widget.arguments![PhotoScreen.argNetUrl];
    if (filePath != null && filePath.isNotEmpty) {
      _contentType = TYPE_FILE;
      _content = filePath;
    } else if (netUrl != null && netUrl.isNotEmpty) {
      _contentType = TYPE_NET;
      _content = netUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? provider;
    if (this._contentType == TYPE_FILE) {
      provider = FileImage(File(this._content ?? ""));
    } else if (this._contentType == TYPE_NET) {
      provider = NetworkImage(this._content ?? "");
    }

    return Layout(
      headerColor: Colors.black,
      borderRadius: BorderRadius.zero,
      header: Header(
        backgroundColor: Colors.black,
        actions: [
          PopupMenuButton(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            icon: Asset.iconSvg('more', width: 24),
            onSelected: (int result) async {
              switch (result) {
                case 0:
                  if ((await Permission.mediaLibrary.request()) != PermissionStatus.granted) {
                    return null;
                  }
                  if ((await Permission.storage.request()) != PermissionStatus.granted) {
                    return null;
                  }

                  File? file = (_contentType == TYPE_FILE) ? File(_content ?? "") : null;
                  String? ext = Path.getFileExt(file) ?? "jpg";
                  logger.i("PhotoScreen - save image file - path:${file?.path}");
                  if (file == null || !await file.exists() || _content == null || _content!.isEmpty) return;

                  File copyFile = File(await Path.getRandomFile(null, SubDirType.download, fileExt: ext));
                  if (!await copyFile.exists()) {
                    await copyFile.create(recursive: true);
                  }
                  copyFile = await file.copy(copyFile.path);
                  logger.i("PhotoScreen - save copy file - path:${copyFile.path}");

                  try {
                    String imageName = 'nkn_' + DateTime.now().millisecondsSinceEpoch.toString() + "." + ext;
                    Uint8List imageBytes = await copyFile.readAsBytes();
                    await Common.saveImageToGallery(imageBytes, imageName, Settings.appName);
                    Toast.show(S.of(Global.appContext).success);
                  } catch (e) {
                    Toast.show(S.of(Global.appContext).failure);
                  }
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
              PopupMenuItem<int>(
                value: 0,
                child: Label(
                  S.of(Global.appContext).save_to_album,
                  type: LabelType.display,
                ),
              ),
            ],
          ),
        ],
      ),
      body: InkWell(
        onTap: () {
          if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
        },
        child: PhotoView(
          imageProvider: provider,
        ),
      ),
    );
  }
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
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

  Future _save() async {
    if ((await Permission.mediaLibrary.request()) != PermissionStatus.granted) {
      return null;
    }
    if ((await Permission.storage.request()) != PermissionStatus.granted) {
      return null;
    }

    File? file = (_contentType == TYPE_FILE) ? File(_content ?? "") : null;
    String ext = Path.getFileExt(file, 'png');
    logger.i("PhotoScreen - save image file - path:${file?.path}");
    if (file == null || !await file.exists() || _content == null || _content!.isEmpty) return;
    String imageName = 'nkn_' + DateTime.now().millisecondsSinceEpoch.toString() + "." + ext;

    Uint8List bytes = await file.readAsBytes();
    Map? result = await ImageGallerySaver.saveImage(bytes, quality: 100, name: imageName, isReturnImagePathOfIOS: true);

    logger.i("PhotoScreen - save copy file - path:${result?["filePath"]}");
    Toast.show(Global.locale((s) => (result?["isSuccess"] ?? false) ? s.success : s.failure, ctx: context));
  }

  @override
  Widget build(BuildContext context) {
    double btnSize = Global.screenWidth() / 10;
    double iconSize = Global.screenWidth() / 15;

    ImageProvider? provider;
    if (this._contentType == TYPE_FILE) {
      provider = FileImage(File(this._content ?? ""));
    } else if (this._contentType == TYPE_NET) {
      provider = NetworkImage(this._content ?? "");
    }

    return Layout(
      headerColor: Colors.black,
      borderRadius: BorderRadius.zero,
      body: InkWell(
        onTap: () {
          if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
        },
        child: Stack(
          children: [
            PhotoView(imageProvider: provider),
            Positioned(
              left: 0,
              right: 0,
              top: Platform.isAndroid ? 45 : 30,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: btnSize / 4),
                  Button(
                    width: btnSize,
                    height: btnSize,
                    backgroundColor: Colors.transparent,
                    padding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                    child: Container(
                      width: btnSize,
                      height: btnSize,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(60),
                        borderRadius: BorderRadius.all(Radius.circular(btnSize / 2)),
                      ),
                      child: Icon(
                        CupertinoIcons.back,
                        color: Colors.white,
                        size: iconSize,
                      ),
                    ),
                    onPressed: () {
                      if (Navigator.of(this.context).canPop()) Navigator.pop(this.context, 0.0);
                    },
                  ),
                  Spacer(),
                  Container(
                    width: btnSize,
                    height: btnSize,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(60),
                      borderRadius: BorderRadius.all(Radius.circular(btnSize / 2)),
                    ),
                    child: PopupMenuButton(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      icon: Asset.iconSvg('more', width: 24),
                      onSelected: (int result) async {
                        switch (result) {
                          case 0:
                            await _save();
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
                        PopupMenuItem<int>(
                          value: 0,
                          child: Label(
                            Global.locale((s) => s.save_to_album, ctx: context),
                            type: LabelType.display,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: btnSize / 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

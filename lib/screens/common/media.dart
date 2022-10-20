import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/layout/drop_down_scale_layout.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaScreen extends BaseStateFulWidget {
  static final String routeName = "/media";
  static final String argContent = "content";
  static final String argContentType = "content_type";

  static const CONTENT_TYPE_FILE_PATH = 0;

  static Future go(BuildContext context, {dynamic content, int type = CONTENT_TYPE_FILE_PATH}) {
    if (content == null) return Future.value(null);
    return Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        transitionDuration: Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: MediaScreen(
              arguments: {
                argContent: content,
                argContentType: type,
              },
            ),
          );
        },
      ),
    );
  }

  final Map<String, dynamic>? arguments;

  MediaScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _MediaScreenState createState() => _MediaScreenState();
}

class _MediaScreenState extends BaseStateFulWidgetState<MediaScreen> with SingleTickerProviderStateMixin {
  final double dragQuitOffsetY = Global.screenHeight() / 6;

  dynamic _content;
  int _type = MediaScreen.CONTENT_TYPE_FILE_PATH;

  bool hideComponents = false;
  double bgOpacity = 1;

  @override
  void onRefreshArguments() {
    _content = widget.arguments![MediaScreen.argContent];
    _type = widget.arguments![MediaScreen.argContentType];
  }

  Future _save() async {
    if ((await Permission.mediaLibrary.request()) != PermissionStatus.granted) {
      return null;
    }
    if ((await Permission.storage.request()) != PermissionStatus.granted) {
      return null;
    }

    // File? file = (_contentType == TYPE_FILE) ? File(_content ?? "") : null;
    // String ext = Path.getFileExt(file, FileHelper.DEFAULT_IMAGE_EXT);
    // logger.i("MediaScreen - save image file - path:${file?.path}");
    // if (file == null || !await file.exists() || _content == null || (_content?.isEmpty == true)) return;
    // String imageName = 'nkn_' + DateTime.now().millisecondsSinceEpoch.toString() + "." + ext;
    //
    // Uint8List bytes = await file.readAsBytes();
    // Map? result = await ImageGallerySaver.saveImage(bytes, quality: 100, name: imageName, isReturnImagePathOfIOS: true);
    //
    // logger.i("MediaScreen - save copy file - path:${result?["filePath"]}");
    // Toast.show(Global.locale((s) => (result?["isSuccess"] ?? false) ? s.success : s.failure, ctx: context));
  }

  Future _share() async {
    //
  }

  @override
  Widget build(BuildContext context) {
    int alpha = (255 * bgOpacity) ~/ 1;

    double btnSize = Global.screenWidth() / 10;
    double iconSize = Global.screenWidth() / 15;

    Widget content;
    if (_type == MediaScreen.CONTENT_TYPE_FILE_PATH) {
      content = Center(child: Image.file(File(_content), fit: BoxFit.contain));
    } else {
      content = SizedBox.shrink();
    }

    return Layout(
      bodyColor: Colors.black.withAlpha(alpha),
      headerColor: Colors.transparent,
      borderRadius: BorderRadius.zero,
      body: DropDownScaleLayout(
        triggerOffsetY: dragQuitOffsetY,
        onTap: () {
          setState(() {
            hideComponents = !hideComponents;
          });
        },
        onDragStart: () {
          setState(() {
            hideComponents = true;
          });
        },
        onDragUpdate: (percent) {
          if ((1 - percent) >= 0) {
            setState(() {
              bgOpacity = 1 - percent;
            });
          }
        },
        onDragEnd: (quiet) {
          if (quiet) {
            if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
          } else {
            setState(() {
              hideComponents = false;
              bgOpacity = 1;
            });
          }
        },
        content: Stack(
          children: [
            content,
            // top
            hideComponents
                ? SizedBox.shrink()
                : Positioned(
                    left: 0,
                    right: 0,
                    top: Platform.isAndroid ? 40 : 35,
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
                              color: Colors.black.withAlpha(60),
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
                      ],
                    ),
                  ),
            // bottom
            hideComponents
                ? SizedBox.shrink()
                : Positioned(
                    left: 0,
                    right: 0,
                    bottom: 15,
                    child: Row(
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
                              color: Colors.black.withAlpha(60),
                              borderRadius: BorderRadius.all(Radius.circular(btnSize / 2)),
                            ),
                            child: Icon(
                              Icons.share,
                              color: Colors.white,
                              size: iconSize,
                            ),
                          ),
                          onPressed: () {
                            // TODO:GG share
                          },
                        ),
                        Spacer(),
                        Button(
                          width: btnSize,
                          height: btnSize,
                          backgroundColor: Colors.transparent,
                          padding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                          child: Container(
                            width: btnSize,
                            height: btnSize,
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(60),
                              borderRadius: BorderRadius.all(Radius.circular(btnSize / 2)),
                            ),
                            child: Icon(
                              CupertinoIcons.arrow_down_to_line,
                              color: Colors.white,
                              size: iconSize,
                            ),
                          ),
                          onPressed: () {
                            // TODO:GG save
                          },
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

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

class VideoScreen extends BaseStateFulWidget {
  static final String routeName = "/video";
  static final String argFilePath = "file_path";
  static final String argThumbnail = "thumbnail_path";
  static final String argNetUrl = "net_url";

  static Future go(BuildContext? context, {String? filePath, String? thumbnailPath, String? netUrl}) {
    if (context == null) return Future.value(null);
    if ((filePath == null || filePath.isEmpty) && (netUrl == null || netUrl.isEmpty)) return Future.value(null);
    return Navigator.pushNamed(context, routeName, arguments: {
      argFilePath: filePath,
      argThumbnail: thumbnailPath,
      argNetUrl: netUrl,
    });
  }

  final Map<String, dynamic>? arguments;

  VideoScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _VideoScreenState createState() => _VideoScreenState();
}

class _VideoScreenState extends BaseStateFulWidgetState<VideoScreen> with SingleTickerProviderStateMixin {
  static const int TYPE_FILE = 1;
  static const int TYPE_NET = 2;

  int? _contentType;
  String? _content;

  VideoPlayerController? _controller;
  bool isPlaying = false;

  @override
  void onRefreshArguments() {
    String? filePath = widget.arguments?[VideoScreen.argFilePath];
    String? netUrl = widget.arguments?[VideoScreen.argNetUrl];
    bool isChanged = false;
    if (filePath != null && filePath.isNotEmpty) {
      isChanged = _content != filePath;
      _contentType = TYPE_FILE;
      _content = filePath;
    } else if (netUrl != null && netUrl.isNotEmpty) {
      isChanged = _content != netUrl;
      _contentType = TYPE_NET;
      _content = netUrl;
    }
    if (isChanged) {
      _initController();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _controller?.dispose();
  }

  _initController() {
    if (_content?.isNotEmpty == true) {
      if (_contentType == TYPE_NET) {
        _controller = VideoPlayerController.network(_content ?? "");
      } else if (_contentType == TYPE_FILE) {
        File file = File(_content ?? "");
        if (file.existsSync()) {
          _controller = VideoPlayerController.file(file);
        }
      }
    }
    _controller?.initialize().then((_) {
      // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
      setState(() {});
    });
    _controller?.addListener(() {
      if (isPlaying != _controller?.value.isPlaying) {
        setState(() {});
        isPlaying = _controller?.value.isPlaying ?? false;
      }
    });
  }

  _togglePlay() {
    setState(() {
      (_controller?.value.isPlaying == true) ? _controller?.pause() : _controller?.play();
    });
  }

  Future _save() async {
    if (Platform.isIOS) {
      if ((await Permission.photos.request()) != PermissionStatus.granted) {
        return null;
      }
    } else if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt <= 32) {
        if ((await Permission.storage.request()) != PermissionStatus.granted) {
          return null;
        }
      }
    }

    File? file = (_contentType == TYPE_FILE) ? File(_content ?? "") : null;
    String ext = Path.getFileExt(file, FileHelper.DEFAULT_VIDEO_EXT);
    logger.i("VideoScreen - get video file - path:${file?.path}");
    if (file == null || !await file.exists() || _content == null || (_content?.isEmpty == true)) return;
    String videoName = 'nkn_' + DateTime.now().millisecondsSinceEpoch.toString() + "." + ext;

    Map? result = await ImageGallerySaverPlus.saveFile(file.absolute.path, name: videoName, isReturnPathOfIOS: true);

    logger.i("VideoScreen - save copy file - path:${result?["filePath"]}");
    Toast.show(Settings.locale((s) => (result?["isSuccess"] ?? false) ? s.success : s.failure, ctx: context));
  }

  @override
  Widget build(BuildContext context) {
    double playSize = Settings.screenWidth() / 5;
    double btnSize = Settings.screenWidth() / 10;
    double iconSize = Settings.screenWidth() / 15;

    return Layout(
      bodyColor: Colors.black,
      headerColor: Colors.black,
      borderRadius: BorderRadius.zero,
      body: InkWell(
        onTap: () {
          this._togglePlay();
        },
        child: Stack(
          children: [
            (_controller?.value.isInitialized == true)
                ? Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : SizedBox.shrink(),
            (_controller != null && _controller?.value.isPlaying == false)
                ? Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Icon(
                      CupertinoIcons.play_circle,
                      size: playSize,
                      color: Colors.white,
                    ),
                  )
                : SizedBox.shrink(),
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
                      if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
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
                            Settings.locale((s) => s.save_to_album, ctx: context),
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

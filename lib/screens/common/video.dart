import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button_icon.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/native/common.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

class VideoScreen extends BaseStateFulWidget {
  static final String routeName = "/video";
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

  @override
  void onRefreshArguments() {
    String? filePath = widget.arguments![VideoScreen.argFilePath];
    String? netUrl = widget.arguments![VideoScreen.argNetUrl];
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
      if (_contentType == TYPE_FILE) {
        _controller = VideoPlayerController.network(_content ?? "");
      } else if (_contentType == TYPE_NET) {
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
  }

  _togglePlay() {
    setState(() {
      (_controller?.value.isPlaying == true) ? _controller?.pause() : _controller?.play();
    });
  }

  @override
  Widget build(BuildContext context) {
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
              // FUTURE: HideBar
              switch (result) {
                case 0:
                  if ((await Permission.mediaLibrary.request()) != PermissionStatus.granted) {
                    return null;
                  }
                  if ((await Permission.storage.request()) != PermissionStatus.granted) {
                    return null;
                  }

                  File? file = (_contentType == TYPE_FILE) ? File(_content ?? "") : null;
                  String ext = Path.getFileExt(file, 'mp4');
                  logger.i("VideoScreen - get video file - path:${file?.path}");
                  if (file == null || !await file.exists() || _content == null || _content!.isEmpty) return;

                  File copyFile = File(await Path.createRandomFile(null, DirType.download, fileExt: ext));
                  copyFile = await file.copy(copyFile.path);
                  logger.i("VideoScreen - save copy file - path:${copyFile.path}");

                  String videoName = 'nkn_' + DateTime.now().millisecondsSinceEpoch.toString() + "." + ext;
                  Uint8List videoBytes = await copyFile.readAsBytes();
                  bool ok = await Common.saveMediaToGallery(videoBytes, videoName, Settings.appName);
                  Toast.show(Global.locale((s) => ok ? s.success : s.failure, ctx: context));
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
        ],
      ),
      body: InkWell(
        onTap: () {
          // FUTURE: ControllerView
          this._togglePlay();
        },
        child: Stack(
          children: [
            (_controller != null) ? VideoPlayer(_controller!) : SizedBox(),
            (_controller != null && _controller?.value.isPlaying == false)
                ? Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ButtonIcon(
                      width: 50,
                      height: 50,
                      // icon: Asset.iconSvg('close', width: 16),
                      icon: Icon(
                        CupertinoIcons.play_circle,
                        size: Global.screenWidth() / 4,
                        color: Colors.white,
                      ),
                      onPressed: () => this._togglePlay(),
                    ),
                  )
                : SizedBox(),
          ],
        ),
      ),
    );
  }
}

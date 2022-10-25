import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:card_swiper/card_swiper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/layout/drop_down_scale_layout.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:synchronized/synchronized.dart';
import 'package:video_player/video_player.dart';

class MediaScreen extends BaseStateFulWidget {
  static final String routeName = "/media";
  static final String argTarget = "target";
  static final String argMsgId = "msgId";
  static final String argMedias = "medias";

  static Future go(BuildContext context, List<Map<String, dynamic>>? medias, {String? target, String? msgId}) {
    if (medias == null || medias.isEmpty) return Future.value(null);
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
                argTarget: target,
                argMsgId: msgId,
                argMedias: medias,
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

  // ignore: close_sinks
  static StreamController<List<Map<String, dynamic>>> _onFetchController = StreamController<List<Map<String, dynamic>>>.broadcast();
  static StreamSink<List<Map<String, dynamic>>> get onFetchSink => _onFetchController.sink;
  static Stream<List<Map<String, dynamic>>> get onFetchStream => _onFetchController.stream;

  static List<Map<String, dynamic>>? createFetchRequest(String? target, String? msgId) {
    if (target == null || target.isEmpty) return null;
    return [
      {"type": "request", "target": target, "msgId": msgId}
    ];
  }

  static createFetchResponse(String? target, String? msgId, List<Map<String, dynamic>> medias) {
    List<Map<String, dynamic>> data = [];
    data.add({"type": "response", "target": target, "msgId": msgId});
    data.addAll(medias);
    return data;
  }

  static Map<String, dynamic>? createMediasItemByImagePath(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    return {
      "mediaType": "image",
      "contentType": "path",
      "content": imagePath,
    };
  }

  static Map<String, dynamic>? createMediasItemByVideoPath(String? contentPath, String? thumbnailPath) {
    if (contentPath == null || contentPath.isEmpty) return null;
    return {
      "mediaType": "video",
      "contentType": "path",
      "content": contentPath,
      "thumbnail": thumbnailPath,
    };
  }
}

class _MediaScreenState extends BaseStateFulWidgetState<MediaScreen> with SingleTickerProviderStateMixin {
  final double dragQuitOffsetY = Global.screenHeight() / 6;

  StreamSubscription? _onFetchMediasSubscription;
  final int fetchLimit = 3;
  bool fetchLoading = false;

  String? _target;
  String? _msgId;

  List<Map<String, dynamic>> _medias = [];
  int _showIndex = 0;

  VideoPlayerController? _videoController;
  bool _isVideoPlaying = false;
  int _videoInitIndex = -1;
  Lock _videoLock = new Lock();

  bool hideComponents = false;
  double bgOpacity = 1;

  @override
  void onRefreshArguments() {
    _target = widget.arguments?[MediaScreen.argTarget]?.toString();
    _msgId = widget.arguments?[MediaScreen.argMsgId]?.toString();
    _medias = widget.arguments?[MediaScreen.argMedias] ?? _medias;
  }

  @override
  void initState() {
    super.initState();
    // fetch
    _onFetchMediasSubscription = MediaScreen.onFetchStream.listen((response) {
      if (response.isEmpty || response[0].isEmpty) return;
      String type = response[0]["type"]?.toString() ?? "";
      if (type != "response") return;
      String target = response[0]["target"]?.toString() ?? "";
      if (target != _target) return;
      String msgId = response[0]["msgId"]?.toString() ?? "";
      var medias = response..removeAt(0);
      if (medias.isEmpty) return;
      if (!fetchLoading) return;
      setState(() {
        _msgId = msgId;
        _medias += medias;
      });
      fetchLoading = false;
    });
    _tryFetchMedias();
    // video first
    _initVideoController(_showIndex); // await
  }

  @override
  void dispose() {
    super.dispose();
    _videoController?.dispose();
    _onFetchMediasSubscription?.cancel();
  }

  void _tryFetchMedias() {
    if ((_showIndex + 1) < (_medias.length - fetchLimit)) return;
    if (fetchLoading) return;
    fetchLoading = true;
    List<Map<String, dynamic>>? request = MediaScreen.createFetchRequest(_target, _msgId);
    if (request != null) MediaScreen.onFetchSink.add(request);
  }

  void _initVideoController(int index) async {
    _videoController?.pause();
    Map<String, dynamic>? media = _medias[index];
    if (media.isEmpty) return;
    String mediaType = media["mediaType"] ?? "";
    if (mediaType != "video") return;
    String contentType = media["contentType"] ?? "";
    String content = media["content"] ?? "";
    if (content.isEmpty) return;
    await _videoLock.synchronized(() async {
      if (_videoInitIndex == index) return;
      await _videoController?.dispose();
      _videoController = null;
      if (contentType == "path") {
        File file = File(content);
        if (file.existsSync()) {
          _videoController = VideoPlayerController.file(file);
        }
      }
      _videoController?.initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {});
      });
      _videoController?.addListener(() {
        if (_isVideoPlaying != _videoController?.value.isPlaying) {
          setState(() {
            _isVideoPlaying = _videoController?.value.isPlaying ?? false;
          });
        }
      });
      _videoInitIndex = index;
    });
  }

  bool? _toggleVideoPlay({bool? play}) {
    if ((_showIndex < 0) || (_showIndex >= _medias.length)) return null;
    Map<String, dynamic>? media = _medias[_showIndex];
    if (media.isEmpty) return null;
    String mediaType = media["mediaType"] ?? "";
    String content = media["content"] ?? "";
    if ((mediaType != "video") || content.isEmpty) return null;
    if ((_videoController == null) || (_videoController?.value.isInitialized != true)) return null;
    // play
    bool? needPlay = play;
    if (needPlay == null) needPlay = !(_videoController?.value.isPlaying == true);
    setState(() {
      (needPlay == true) ? _videoController?.play() : _videoController?.pause();
    });
    return needPlay;
  }

  Future _save() async {
    // permission
    if ((await Permission.mediaLibrary.request()) != PermissionStatus.granted) {
      return null;
    }
    if ((await Permission.storage.request()) != PermissionStatus.granted) {
      return null;
    }
    // data
    if ((_showIndex < 0) || (_showIndex >= _medias.length)) return null;
    Map<String, dynamic>? media = _medias[_showIndex];
    if (media.isEmpty) return null;
    String mediaType = media["mediaType"] ?? "";
    String contentType = media["contentType"] ?? "";
    String content = media["content"] ?? "";
    // save
    if (mediaType == "image") {
      if ((contentType == "path") && content.isNotEmpty) {
        File file = File(content);
        if (!file.existsSync()) return;
        logger.i("MediaScreen - save image file - path:${file.path}");
        Uint8List bytes = await file.readAsBytes();
        String ext = Path.getFileExt(file, FileHelper.DEFAULT_IMAGE_EXT);
        String mediaName = 'nkn_' + DateTime.now().millisecondsSinceEpoch.toString() + "." + ext;
        Map? result = await ImageGallerySaver.saveImage(bytes, quality: 100, name: mediaName, isReturnImagePathOfIOS: true);
        logger.i("MediaScreen - save copy image - path:${result?["filePath"]}");
        Toast.show(Global.locale((s) => (result?["isSuccess"] ?? false) ? s.success : s.failure, ctx: context));
      }
    } else if (mediaType == "video") {
      if ((contentType == "path") && content.isNotEmpty) {
        File file = File(content);
        if (!file.existsSync()) return;
        logger.i("MediaScreen - save video file - path:${file.path}");
        String ext = Path.getFileExt(file, FileHelper.DEFAULT_VIDEO_EXT);
        String mediaName = 'nkn_' + DateTime.now().millisecondsSinceEpoch.toString() + "." + ext;
        Map? result = await ImageGallerySaver.saveFile(file.absolute.path, name: mediaName, isReturnPathOfIOS: true);
        logger.i("MediaScreen - save copy video - path:${result?["filePath"]}");
        Toast.show(Global.locale((s) => (result?["isSuccess"] ?? false) ? s.success : s.failure, ctx: context));
      }
    }
  }

  Future _share() async {
    // data
    if ((_showIndex < 0) || (_showIndex >= _medias.length)) return null;
    Map<String, dynamic>? media = _medias[_showIndex];
    if (media.isEmpty) return null;
    String mediaType = media["mediaType"] ?? "";
    String contentType = media["contentType"] ?? "";
    String content = media["content"] ?? "";
    // share
    if (mediaType == "image") {
      if ((contentType == "path") && content.isNotEmpty) {
        File file = File(content);
        if (!file.existsSync()) return;
        logger.i("MediaScreen - share image file - path:${file.path}");
        String mimeType = Platform.isAndroid ? "image/*" : "image/jpeg";
        Share.shareFiles([file.path], mimeTypes: [mimeType]);
      }
    } else if (mediaType == "video") {
      if ((contentType == "path") && content.isNotEmpty) {
        File file = File(content);
        if (!file.existsSync()) return;
        logger.i("MediaScreen - share video file - path:${file.path}");
        String mimeType = Platform.isAndroid ? "video/*" : "video/mp4";
        Share.shareFiles([file.path], mimeTypes: [mimeType]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int alpha = (255 * bgOpacity) ~/ 1;
    double iconSize = Global.screenWidth() / 15;
    double btnSize = Global.screenWidth() / 10;
    double playSize = Global.screenWidth() / 5;
    return Layout(
      bodyColor: Colors.black.withAlpha(alpha),
      headerColor: Colors.transparent,
      borderRadius: BorderRadius.zero,
      body: DropDownScaleLayout(
        triggerOffsetY: dragQuitOffsetY,
        onTap: () {
          bool nextHide = _toggleVideoPlay() ?? !hideComponents;
          setState(() {
            hideComponents = nextHide;
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
            Swiper(
              loop: false,
              autoplay: false,
              index: _showIndex,
              itemCount: _medias.length,
              onIndexChanged: (index) {
                // logger.i("-----> 111 index:$index");
                if ((index < 0) || (index >= _medias.length)) return;
                setState(() {
                  _showIndex = index;
                  _isVideoPlaying = false;
                  hideComponents = false;
                  bgOpacity = 1;
                });
                _initVideoController(index); // await
                _tryFetchMedias();
              },
              itemBuilder: (BuildContext context, int index) {
                // logger.i("-----> 222 index:$index");
                if ((index < 0) || (index >= _medias.length)) return SizedBox.shrink();
                Map<String, dynamic>? media = _medias[index];
                if (media.isEmpty) return SizedBox.shrink();
                String mediaType = media["mediaType"] ?? "";
                String contentType = media["contentType"] ?? "";
                String content = media["content"] ?? "";
                String thumbnail = media["thumbnail"] ?? "";
                // widget
                Widget child;
                if (mediaType == "image") {
                  if ((contentType == "path") && content.isNotEmpty) {
                    child = Center(
                      child: Image.file(
                        File(content),
                        fit: BoxFit.contain,
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                          // logger.i("-----> 333 index:$index - frame$frame - loaded:$wasSynchronouslyLoaded");
                          return ((frame != null) || wasSynchronouslyLoaded)
                              ? child
                              : SpinKitRing(
                                  color: Colors.white,
                                  lineWidth: btnSize / 10,
                                  size: btnSize,
                                );
                        },
                      ),
                    );
                  } else {
                    child = SizedBox.shrink();
                  }
                } else if (mediaType == "video") {
                  if ((contentType == "path") && content.isNotEmpty) {
                    bool isReady = (index == _showIndex) && (_videoController?.value.isInitialized == true);
                    bool isPlaying = (index == _showIndex) && (_videoController?.value.isPlaying == true);
                    child = Stack(children: [
                      thumbnail.isNotEmpty
                          ? Positioned(
                              left: 0,
                              right: 0,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                constraints: BoxConstraints(),
                                child: Image.file(
                                  File(thumbnail),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            )
                          : SizedBox.shrink(),
                      isReady
                          ? Center(
                              child: AspectRatio(
                                aspectRatio: _videoController!.value.aspectRatio,
                                child: VideoPlayer(_videoController!),
                              ),
                            )
                          : SizedBox.shrink(),
                      isReady
                          ? (isPlaying
                              ? SizedBox.shrink()
                              : Positioned(
                                  left: 0,
                                  right: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: Icon(
                                    CupertinoIcons.play_circle,
                                    size: playSize,
                                    color: Colors.white,
                                  ),
                                ))
                          : SpinKitRing(
                              color: Colors.white,
                              lineWidth: playSize / 12,
                              size: playSize / 1.2,
                            ),
                    ]);
                  } else {
                    child = SizedBox.shrink();
                  }
                } else {
                  child = SizedBox.shrink();
                }
                return child;
              },
            ),
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
                          onPressed: () => _share(),
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
                          onPressed: () => _save(),
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

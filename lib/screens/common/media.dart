import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:nmobile/utils/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:synchronized/synchronized.dart';
import 'package:video_player/video_player.dart';

class MediaScreen extends BaseStateFulWidget {
  static final String routeName = "/media";
  static final String argMedias = "medias";
  static final String argTarget = "target";
  static final String argLeftMsgId = "leftMsgId";
  static final String argRightMsgId = "rightMsgId";

  static Future go(BuildContext? context, List<Map<String, dynamic>>? medias, {String? target, String? leftMsgId, String? rightMsgId}) {
    if (context == null) return Future.value(null);
    if (medias == null || medias.isEmpty) return Future.value(null);
    if (leftMsgId == null && rightMsgId != null) leftMsgId = rightMsgId;
    if (rightMsgId == null && leftMsgId != null) rightMsgId = leftMsgId;
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
                argMedias: medias,
                argTarget: target,
                argLeftMsgId: leftMsgId,
                argRightMsgId: rightMsgId,
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

  static List<Map<String, dynamic>>? createFetchRequest(String? target, bool isLeft, String? msgId) {
    if (target == null || target.isEmpty) return null;
    return [
      {"type": "request", "target": target, "isLeft": isLeft, "msgId": msgId}
    ];
  }

  static createFetchResponse(String? target, bool isLeft, String? msgId, List<Map<String, dynamic>> medias) {
    List<Map<String, dynamic>> data = [];
    data.add({"type": "response", "target": target, "isLeft": isLeft, "msgId": msgId});
    data.addAll(medias);
    return data;
  }

  static Map<String, dynamic>? createMediasItemByImagePath(String? id, String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    return {
      "id": id,
      "mediaType": "image",
      "contentType": "path",
      "content": imagePath,
    };
  }

  static Map<String, dynamic>? createMediasItemByVideoPath(String? id, String? contentPath, String? thumbnailPath) {
    if (contentPath == null || contentPath.isEmpty) return null;
    return {
      "id": id,
      "mediaType": "video",
      "contentType": "path",
      "content": contentPath,
      "thumbnail": thumbnailPath,
    };
  }
}

class _MediaScreenState extends BaseStateFulWidgetState<MediaScreen> with SingleTickerProviderStateMixin {
  final double dragQuitOffsetY = Global.screenHeight() / 6;

  ParallelQueue _queue = ParallelQueue("media_fetch", onLog: (log, error) => error ? logger.w(log) : null);
  StreamSubscription? _onFetchMediasSubscription;

  PageController? _pageController;
  List<Map<String, dynamic>> _medias = [];
  int _dataIndex = 0;
  final int fetchLimit = 3;

  String? _target;
  String? _leftMsgId;
  bool _leftFetchLoading = false;
  String? _rightMsgId;
  bool _rightFetchLoading = false;

  VideoPlayerController? _videoController;
  bool _isVideoPlaying = false;
  int _videoInitIndex = -1;
  Lock _videoLock = new Lock();

  bool hideComponents = false;
  double bgOpacity = 1;

  @override
  void onRefreshArguments() {
    _target = widget.arguments?[MediaScreen.argTarget]?.toString();
    _leftMsgId = widget.arguments?[MediaScreen.argLeftMsgId]?.toString();
    _rightMsgId = widget.arguments?[MediaScreen.argRightMsgId]?.toString();
    _medias = widget.arguments?[MediaScreen.argMedias] ?? _medias;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _dataIndex);
    // fetch
    _onFetchMediasSubscription = MediaScreen.onFetchStream.listen((response) {
      if (response.isEmpty || response[0].isEmpty) return;
      String type = response[0]["type"]?.toString() ?? "";
      if (type != "response") return;
      String target = response[0]["target"]?.toString() ?? "";
      if (target != _target) return;
      bool isLeft = response[0]["isLeft"] ?? true;
      String msgId = response[0]["msgId"]?.toString() ?? "";
      var medias = response..removeAt(0);
      if (medias.isEmpty) return;
      _queue.add(() async {
        if (isLeft) {
          if (!_leftFetchLoading) return;
          setState(() {
            _leftMsgId = msgId;
            _dataIndex = _dataIndex + medias.length;
            _medias.insertAll(0, medias.reversed);
            _pageController?.jumpToPage(_dataIndex);
          });
          _leftFetchLoading = false;
        } else {
          if (!_rightFetchLoading) return;
          setState(() {
            _rightMsgId = msgId;
            // _dataIndex = _dataIndex;
            _medias.addAll(medias.reversed);
            // _pageController?.jumpToPage(_dataIndex);
          });
          _rightFetchLoading = false;
        }
      });
    });
    // data
    _tryFetchMedias();
    // video
    _initVideoController(_dataIndex); // await
  }

  @override
  void dispose() {
    super.dispose();
    _pageController?.dispose();
    _videoController?.dispose();
    _onFetchMediasSubscription?.cancel();
  }

  void _tryFetchMedias() {
    if ((_dataIndex + 1) <= fetchLimit) {
      if (!_leftFetchLoading) {
        _leftFetchLoading = true;
        List<Map<String, dynamic>>? request = MediaScreen.createFetchRequest(_target, true, _leftMsgId);
        if (request != null) MediaScreen.onFetchSink.add(request);
      }
    }
    if (_dataIndex >= (_medias.length - fetchLimit)) {
      if (!_rightFetchLoading) {
        _rightFetchLoading = true;
        List<Map<String, dynamic>>? request = MediaScreen.createFetchRequest(_target, false, _rightMsgId);
        if (request != null) MediaScreen.onFetchSink.add(request);
      }
    }
  }

  void _initVideoController(int index) async {
    _videoController?.pause();
    // logger.i("-----> 333 - index:$index - size:${_medias.length}");
    if ((index < 0) || (index >= _medias.length)) return null;
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

  bool? _toggleVideoPlay(int index, {bool? play}) {
    if ((index < 0) || (index >= _medias.length)) return null;
    Map<String, dynamic>? media = _medias[index];
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

  Future _save(int index) async {
    // permission
    if ((await Permission.mediaLibrary.request()) != PermissionStatus.granted) {
      return null;
    }
    if ((await Permission.storage.request()) != PermissionStatus.granted) {
      return null;
    }
    // data
    if ((index < 0) || (index >= _medias.length)) return null;
    Map<String, dynamic>? media = _medias[index];
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

  Future _share(int index) async {
    // data
    if ((index < 0) || (index >= _medias.length)) return null;
    Map<String, dynamic>? media = _medias[index];
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
        XFile xFile = XFile(file.path, mimeType: mimeType);
        Share.shareXFiles([xFile]);
      }
    } else if (mediaType == "video") {
      if ((contentType == "path") && content.isNotEmpty) {
        File file = File(content);
        if (!file.existsSync()) return;
        logger.i("MediaScreen - share video file - path:${file.path}");
        String mimeType = Platform.isAndroid ? "video/*" : "video/mp4";
        XFile xFile = XFile(file.path, mimeType: mimeType);
        Share.shareXFiles([xFile]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int alpha = (255 * bgOpacity) ~/ 1;
    double iconSize = Global.screenWidth() / 15;
    double btnSize = Global.screenWidth() / 10;
    double playSize = Global.screenWidth() / 5;
    // logger.i("-----> 000 - index:$_dataIndex - size:${_medias.length}");
    return Layout(
      bodyColor: Colors.black.withAlpha(alpha),
      headerColor: Colors.transparent,
      borderRadius: BorderRadius.zero,
      body: DropDownScaleLayout(
        triggerOffsetY: dragQuitOffsetY,
        onTap: () {
          bool nextHide = _toggleVideoPlay(_dataIndex) ?? !hideComponents;
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
            PageView.builder(
              controller: _pageController,
              itemCount: _medias.length,
              onPageChanged: (index) {
                // logger.i("-----> 222 - index:$index - size:${_medias.length}");
                if ((index < 0) || (index >= _medias.length)) return;
                setState(() {
                  _dataIndex = index;
                  _isVideoPlaying = false;
                  hideComponents = false;
                  bgOpacity = 1;
                });
                _initVideoController(index); // await
                _tryFetchMedias();
              },
              itemBuilder: (BuildContext context, int index) {
                // logger.i("-----> 111 - index:$index  - size:${_medias.length}");
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
                    bool isReady = (index == _dataIndex) && (_videoController?.value.isInitialized == true);
                    bool isPlaying = (index == _dataIndex) && (_videoController?.value.isPlaying == true);
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
                          onPressed: () => _share(_dataIndex),
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
                          onPressed: () => _save(_dataIndex),
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

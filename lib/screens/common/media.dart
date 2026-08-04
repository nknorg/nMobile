import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dismissible_page/dismissible_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/parallel_queue.dart';
import 'package:nmobile/utils/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
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
  final double dragQuitOffsetY = Settings.screenHeight() / 6;

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

  Lock _mediaLoadLock = new Lock();
  String? currentMediaType;

  PhotoViewScaleStateController? _imageScaleController;
  int? _imageInitIndex;

  VideoPlayerController? _videoController;
  int? _videoInitIndex;
  bool _isVideoPlaying = false;

  bool hideComponents = false;

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
    // media
    _loadMedia(_dataIndex); // await
  }

  @override
  void dispose() {
    super.dispose();
    _videoController?.dispose();
    _imageScaleController?.dispose();
    _pageController?.dispose();
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

  Future _loadMedia(int index) async {
    // logger.i("-----> 333 - index:$index - size:${_medias.length}");
    _imageScaleController?.reset();
    _videoController?.pause();
    if ((index < 0) || (index >= _medias.length)) return null;
    Map<String, dynamic>? media = _medias[index];
    if (media.isEmpty) return;
    String mediaType = media["mediaType"] ?? "";
    String content = media["content"] ?? "";
    if (content.isEmpty) return;
    String contentType = media["contentType"] ?? "";
    if (mediaType != currentMediaType) {
      setState(() {
        currentMediaType = mediaType;
      });
    }
    await _mediaLoadLock.synchronized(() async {
      if (mediaType == "image") {
        if (_imageInitIndex == index) return;
        if (_imageScaleController == null) {
          _imageScaleController = PhotoViewScaleStateController();
        }
        if (contentType == "path") {
          if (_imageInitIndex == index) return;
          // nothing
          _imageInitIndex = index;
        } else {
          // nothing
        }
      } else if (mediaType == "video") {
        if (_videoInitIndex == index) return;
        await _videoController?.dispose();
        _videoController = null;
        if (contentType == "path") {
          File file = File(content);
          if (file.existsSync()) {
            _videoController = VideoPlayerController.file(file);
          }
        } else {
          // nothing
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
      }
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
        Map? result = await ImageGallerySaverPlus.saveImage(bytes, quality: 100, name: mediaName, isReturnImagePathOfIOS: true);
        logger.i("MediaScreen - save copy image - path:${result?["filePath"]}");
        Toast.show(Settings.locale((s) => (result?["isSuccess"] ?? false) ? s.success : s.failure, ctx: context));
      }
    } else if (mediaType == "video") {
      if ((contentType == "path") && content.isNotEmpty) {
        File file = File(content);
        if (!file.existsSync()) return;
        logger.i("MediaScreen - save video file - path:${file.path}");
        String ext = Path.getFileExt(file, FileHelper.DEFAULT_VIDEO_EXT);
        String mediaName = 'nkn_' + DateTime.now().millisecondsSinceEpoch.toString() + "." + ext;
        Map? result = await ImageGallerySaverPlus.saveFile(file.absolute.path, name: mediaName, isReturnPathOfIOS: true);
        logger.i("MediaScreen - save copy video - path:${result?["filePath"]}");
        Toast.show(Settings.locale((s) => (result?["isSuccess"] ?? false) ? s.success : s.failure, ctx: context));
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
    double iconSize = Settings.screenWidth() / 20;
    double btnSize = Settings.screenWidth() / 10;
    double btnPad = btnSize * 0.2;
    double playSize = Settings.screenWidth() / 5;
    // logger.i("-----> 000 - index:$_dataIndex - size:${_medias.length}");
    return Stack(
      children: [
        DismissiblePage(
          isFullScreen: true,
          backgroundColor: Colors.black,
          hitTestBehavior: HitTestBehavior.opaque,
          direction: DismissiblePageDismissDirection.multi,
          minScale: .70,
          reverseDuration: const Duration(milliseconds: 200),
          onDismissed: () {
            if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
          },
          onDragUpdate: (info) {
            if ((hideComponents == false) && (info.overallDragValue > 0)) {
              setState(() {
                hideComponents = true;
              });
            } else if ((hideComponents == true) && (info.overallDragValue <= 0)) {
              setState(() {
                hideComponents = false;
              });
            }
          },
          child: PhotoViewGestureDetectorScope(
            axis: Axis.horizontal,
            child: PageView.builder(
              allowImplicitScrolling: true,
              controller: _pageController,
              itemCount: _medias.length,
              onPageChanged: (index) {
                // logger.i("-----> 222 - index:$index - size:${_medias.length}");
                if ((index < 0) || (index >= _medias.length)) return;
                setState(() {
                  _dataIndex = index;
                  _isVideoPlaying = false;
                  hideComponents = false;
                });
                _loadMedia(index); // await
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
                if (content.isEmpty) {
                  child = SizedBox.shrink();
                } else if (mediaType == "image") {
                  if (contentType == "path") {
                    child = PhotoView(
                        onTapUp: (BuildContext context, TapUpDetails details, PhotoViewControllerValue controllerValue) {
                          if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
                        },
                        imageProvider: FileImage(File(content)),
                        backgroundDecoration: const BoxDecoration(color: Colors.transparent),
                        scaleStateController: _imageScaleController,
                        loadingBuilder: (context, event) {
                          return SpinKitRing(
                            color: Colors.white,
                            lineWidth: btnSize / 10,
                            size: btnSize,
                          );
                        });
                  } else {
                    child = SizedBox.shrink();
                  }
                } else if (mediaType == "video") {
                  if (contentType == "path") {
                    bool isReady = (index == _dataIndex) && (_videoController?.value.isInitialized == true);
                    bool isPlaying = (index == _dataIndex) && (_videoController?.value.isPlaying == true);
                    child = Stack(children: [
                      (!isPlaying && thumbnail.isNotEmpty)
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
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _toggleVideoPlay(_dataIndex);
                        },
                        child: SizedBox.expand(),
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
          ),
        ),
        // bottom
        hideComponents
            ? SizedBox.shrink()
            : Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: iconSize - btnPad),
                    currentMediaType != "image"
                        ? Button(
                            width: btnSize + btnPad * 2,
                            height: btnSize + btnPad * 2,
                            backgroundColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(horizontal: btnPad, vertical: btnPad),
                            child: Container(
                              width: btnSize,
                              height: btnSize,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(80),
                                borderRadius: BorderRadius.all(Radius.circular(btnSize / 2)),
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: iconSize,
                              ),
                            ),
                            onPressed: () {
                              if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
                            },
                          )
                        : SizedBox.shrink(),
                    Spacer(),
                    Button(
                      width: btnSize + btnPad * 2,
                      height: btnSize + btnPad * 2,
                      backgroundColor: Colors.transparent,
                      padding: EdgeInsets.symmetric(horizontal: btnPad, vertical: btnPad),
                      child: Container(
                        width: btnSize,
                        height: btnSize,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(80),
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
                    Button(
                      width: btnSize + btnPad * 2,
                      height: btnSize + btnPad * 2,
                      backgroundColor: Colors.transparent,
                      padding: EdgeInsets.symmetric(horizontal: btnPad, vertical: btnPad),
                      child: Container(
                        width: btnSize,
                        height: btnSize,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(80),
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
                    SizedBox(width: iconSize - btnPad),
                  ],
                ),
              ),
      ],
    );
  }
}

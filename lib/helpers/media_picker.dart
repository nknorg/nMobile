import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime_type/mime_type.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as VideoThumbnail;
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
// import 'package:wechat_camera_picker/wechat_camera_picker.dart';

class MediaPicker {
  static Future<List<Map<String, dynamic>>> pickCommons(
    List<String> savePaths, {
    bool compressImage = false,
    bool compressAudio = false,
    bool compressVideo = false,
    int? maxSize,
  }) async {
    // maxNum
    int maxNum = savePaths.length;
    if (maxNum > 9) maxNum = 9;
    if (maxNum < 1) return [];

    // permission
    bool permissionOK = await _isPermissionOK(ImageSource.gallery);
    if (!permissionOK) return [];

    // pick
    List<AssetEntity>? pickedResults;
    try {
      pickedResults = await AssetPicker.pickAssets(
        Settings.appContext,
        pickerConfig: AssetPickerConfig(
          // themeColor: application.theme.primaryColor,
          requestType: RequestType.common,
          pickerTheme: _getTheme(),
          maxAssets: maxNum,
          previewThumbnailSize: Platform.isAndroid ? ThumbnailSize.square(Settings.screenWidth().toInt()) : null,
          gridCount: 4,
          pageSize: 32,
        ),
      );
    } catch (e, st) {
      handleError(e, st);
    }
    if (pickedResults == null || pickedResults.isEmpty) {
      logger.d("MediaPicker - pickCommons - pickedResults = null");
      return [];
    }

    // result
    List<Map<String, dynamic>> pickedMaps = [];
    for (var i = 0; i < pickedResults.length; i++) {
      AssetEntity entity = pickedResults[i];
      // exist
      File? file = (await entity.originFile) ?? (await entity.loadFile(isOrigin: true));
      if (file == null || file.path.isEmpty) {
        logger.e("MediaPicker - pickCommons - pickedResults originFile = null");
        continue;
      }
      // type
      String mimetype = entity.mimeType ?? "";
      if (mimetype.isEmpty) {
        if (entity.typeInt == AssetType.image.index) {
          mimetype = "image";
        } else if (entity.typeInt == AssetType.audio.index) {
          mimetype = "audio";
        } else if (entity.typeInt == AssetType.video.index) {
          mimetype = "video";
        }
      }
      String ext = "";
      List<String>? splits = entity.mimeType?.split("/");
      if (splits != null && splits.length > 1) {
        ext = splits[splits.length - 1];
      }
      if (ext.isEmpty) {
        ext = Path.getFileExt(file, "");
      }
      if (ext.isEmpty) {
        if (entity.typeInt == AssetType.image.index) {
          ext = FileHelper.DEFAULT_IMAGE_EXT;
        } else if (entity.typeInt == AssetType.audio.index) {
          ext = FileHelper.DEFAULT_AUDIO_EXT;
        } else if (entity.typeInt == AssetType.video.index) {
          ext = FileHelper.DEFAULT_VIDEO_EXT;
        }
      }
      // compress
      bool isImage = entity.type == AssetType.image;
      bool isAudio = entity.type == AssetType.audio;
      bool isVideo = entity.type == AssetType.video;
      try {
        if (isImage && compressImage) {
          // FUTURE:GG compress
        } else if (isAudio && compressAudio) {
          // FUTURE:GG compress
        } else if (isVideo && compressVideo) {
          // FUTURE:GG compress
        } else {
          // FUTURE:GG original
        }
      } catch (e, st) {
        handleError(e, st);
      }
      // size
      int size = file.lengthSync();
      if (maxSize != null && maxSize > 0) {
        if (size >= maxSize) {
          Toast.show(Settings.locale((s) => s.file_too_big));
          continue;
        }
      }
      // save
      String savePath;
      if (savePaths.length <= i) {
        savePath = file.absolute.path;
      } else {
        savePath = Path.joinFileExt(savePaths[i], ext);
        File saveFile = File(savePath);
        if (!await saveFile.exists()) {
          await saveFile.create(recursive: true);
        } else {
          await saveFile.delete();
          await saveFile.create(recursive: true);
        }
        saveFile = await file.copy(savePath);
      }
      // map
      if (savePath.isNotEmpty) {
        Map<String, dynamic> params = {
          "path": savePath,
          "size": size,
          "name": null,
          "fileExt": ext.isEmpty ? null : ext,
          "mimeType": mimetype,
          "width": entity.orientatedWidth,
          "height": entity.orientatedHeight,
        };
        if (isAudio || isVideo) {
          params.addAll({"duration": entity.duration});
        }
        pickedMaps.add(params);
      }
      logger.i("MediaPicker - pickCommons - picked success - params:$pickedMaps");
    }
    return pickedMaps;
  }

  /*static Future<Map<String, dynamic>?> takeCommon(
    String? savePath, {
    bool compressImage = false,
    bool compressAudio = false,
    bool compressVideo = false,
    Duration maxDuration = const Duration(seconds: 10),
  }) async {
    // permission
    bool permissionOK = await _isPermissionOK(ImageSource.camera);
    if (!permissionOK) return null;

    // take
    AssetEntity? entity;
    try {
      entity = await CameraPicker.pickFromCamera(
        Settings.appContext,
        pickerConfig: CameraPickerConfig(
          enableRecording: true,
          enableTapRecording: false,
          enableAudio: true,
          enableSetExposure: true,
          enableExposureControlOnPoint: true,
          enablePinchToZoom: true,
          enablePullToZoomInRecord: true,
          shouldDeletePreviewFile: false,
          maximumRecordingDuration: maxDuration,
          theme: _getTheme(),
          resolutionPreset: ResolutionPreset.max,
          imageFormatGroup: ImageFormatGroup.unknown,
        ),
      );
    } catch (e, st) {
      handleError(e, st);
    }

    // file
    File? file = (await entity?.originFile) ?? (await entity?.loadFile(isOrigin: true));
    if (entity == null || file == null || file.path.isEmpty) {
      logger.w("MediaPicker - takeCommon - pickedResults originFile = null");
      return null;
    }

    // type
    String mimetype = entity.mimeType ?? "";
    if (mimetype.isEmpty) {
      if (entity.typeInt == AssetType.image.index) {
        mimetype = "image";
      } else if (entity.typeInt == AssetType.audio.index) {
        mimetype = "audio";
      } else if (entity.typeInt == AssetType.video.index) {
        mimetype = "video";
      }
    }
    String ext = "";
    List<String>? splits = entity.mimeType?.split("/");
    if (splits != null && splits.length > 1) {
      ext = splits[splits.length - 1];
    }
    if (ext.isEmpty) {
      ext = Path.getFileExt(file, "");
    }
    if (ext.isEmpty) {
      if (entity.typeInt == AssetType.image.index) {
        ext = FileHelper.DEFAULT_IMAGE_EXT;
      } else if (entity.typeInt == AssetType.audio.index) {
        ext = FileHelper.DEFAULT_AUDIO_EXT;
      } else if (entity.typeInt == AssetType.video.index) {
        ext = FileHelper.DEFAULT_VIDEO_EXT;
      }
    }

    // compress
    int size = file.lengthSync();
    bool isImage = entity.type == AssetType.image;
    bool isAudio = entity.type == AssetType.audio;
    bool isVideo = entity.type == AssetType.video;
    try {
      if (isImage && compressImage) {
        // FUTURE:GG compress
      } else if (isAudio && compressAudio) {
        // FUTURE:GG compress
      } else if (isVideo && compressVideo) {
        // FUTURE:GG compress
      } else {
        // FUTURE:GG original
      }
    } catch (e, st) {
      handleError(e, st);
    }

    // save
    if (savePath == null || savePath.isEmpty == true) {
      savePath = file.absolute.path;
    } else {
      savePath = Path.joinFileExt(savePath, ext);
      File saveFile = File(savePath);
      if (!await saveFile.exists()) {
        await saveFile.create(recursive: true);
      } else {
        await saveFile.delete();
        await saveFile.create(recursive: true);
      }
      saveFile = await file.copy(savePath);
    }

    // map
    if (savePath.isNotEmpty) {
      Map<String, dynamic> params = {
        "path": savePath,
        "size": size,
        "name": null,
        "fileExt": ext.isEmpty ? null : ext,
        "mimeType": mimetype,
        "width": (Platform.isAndroid && isImage) ? null : entity.orientatedWidth,
        "height": (Platform.isAndroid && isImage) ? null : entity.orientatedHeight,
      };
      if (isAudio || isVideo) {
        params.addAll({"duration": entity.duration});
      }
      logger.i("MediaPicker - takeCommon - picked success - params:${params.toString()} - entity${entity.toString()}");
      return params;
    }
    logger.w("MediaPicker - takeCommon - picked fail");
    return null;
  }*/

  static Future<Map<String, dynamic>?> takeImage(String? savePath, {bool compress = false}) async {
    // permission
    bool permissionOK = await _isPermissionOK(ImageSource.camera);
    if (!permissionOK) return null;

    // pick
    XFile? pickedResult;
    try {
      pickedResult = await ImagePicker().pickImage(source: ImageSource.camera); // imageQuality: compressQuality  -> ios no enable
    } catch (e, st) {
      handleError(e, st);
    }
    if (pickedResult == null || pickedResult.path.isEmpty) {
      logger.w("MediaPicker - takeImage - pickedResult == null");
      return null;
    }

    // type
    File file = File(pickedResult.path);
    String mimetype = "image";
    String ext = Path.getFileExt(file, "");
    if (ext.isEmpty) ext = FileHelper.DEFAULT_IMAGE_EXT;

    // compress
    int size = file.lengthSync();
    try {
      if (compress) {
        // FUTURE:GG compress
      } else {
        // FUTURE:GG original
      }
    } catch (e, st) {
      handleError(e, st);
    }

    // save
    if (savePath == null || savePath.isEmpty == true) {
      savePath = file.absolute.path;
    } else {
      savePath = Path.joinFileExt(savePath, ext);
      File saveFile = File(savePath);
      if (!await saveFile.exists()) {
        await saveFile.create(recursive: true);
      } else {
        await saveFile.delete();
        await saveFile.create(recursive: true);
      }
      saveFile = await file.copy(savePath);
    }

    // map
    if (savePath.isNotEmpty) {
      Map<String, dynamic> params = {
        "path": savePath,
        "size": size,
        "name": null,
        "fileExt": ext.isEmpty ? null : ext,
        "mimeType": mimetype,
        "width": null,
        "height": null,
        "duration": null,
      };
      logger.i("MediaPicker - takeImage - picked success - params:${params.toString()}");
      return params;
    }
    logger.w("MediaPicker - takeImage - picked fail");
    return null;
  }

  static Future<File?> pickImage({
    CropStyle? cropStyle,
    CropAspectRatio? cropRatio,
    int? maxSize,
    int? bestSize,
    String? savePath,
  }) async {
    // permission
    bool permissionOK = await _isPermissionOK(ImageSource.gallery);
    if (!permissionOK) return null;

    // pick
    List<AssetEntity>? pickedResults;
    try {
      pickedResults = await AssetPicker.pickAssets(
        Settings.appContext,
        pickerConfig: AssetPickerConfig(
          themeColor: application.theme.primaryColor,
          requestType: RequestType.image,
          maxAssets: 1,
          gridCount: 3,
          pageSize: 30,
        ),
      );
    } catch (e, st) {
      handleError(e, st);
    }
    if (pickedResults == null || pickedResults.isEmpty) {
      logger.d("MediaPicker - pickImage - pickedResults = null");
      return null;
    }

    // convert
    File? pickedFile = (await pickedResults[0].originFile) ?? (await pickedResults[0].loadFile(isOrigin: false));
    if (pickedFile == null || pickedFile.path.isEmpty) {
      logger.e("MediaPicker - pickImage - pickedFile = null");
      return null;
    }
    logger.i("MediaPicker - pickImage - picked - path:${pickedFile.path}");
    pickedFile.length().then((value) {
      logger.i('MediaPicker - pickImage - picked - size:${Format.flowSize(value.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
    });

    // crop
    pickedFile = await _cropImage(pickedFile, cropStyle, cropRatio: cropRatio, quality: 20, width: 400, height: 400);
    if (pickedFile == null) {
      logger.w('MediaPicker - pickImage - croppedFile = null');
      return null;
    }

    // compress
    pickedFile = await compressImageBySize(pickedFile, maxSize: maxSize ?? 0, bestSize: bestSize ?? 0, toast: true);
    if (pickedFile == null) {
      logger.w('MediaPicker - pickImage - compress = null');
      return null;
    }

    // save
    String fileExt = Path.getFileExt(pickedFile, FileHelper.DEFAULT_IMAGE_EXT);
    if (savePath == null || savePath.isEmpty) {
      savePath = await Path.getRandomFile(null, DirType.cache, fileExt: fileExt);
    } else {
      savePath = Path.joinFileExt(savePath, fileExt);
    }
    File returnFile = File(savePath);
    if (!await returnFile.exists()) {
      await returnFile.create(recursive: true);
    } else {
      await returnFile.delete();
      await returnFile.create(recursive: true);
    }
    returnFile = await pickedFile.copy(savePath);

    logger.i('MediaPicker - pickImage - return - path:${returnFile.path}');
    return returnFile;
  }

  static Future<File?> _cropImage(File? original, CropStyle? cropStyle, {CropAspectRatio? cropRatio, int quality = 50, int? width, int? height}) async {
    if (original == null) return null;
    if (cropStyle == null) return original;
    // gif
    bool isGif = (mime(original.path)?.indexOf('image/gif') ?? -1) >= 0;
    if (isGif) return original;
    // crop
    File? cropFile;
    try {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: original.absolute.path,
        compressFormat: ImageCompressFormat.png,
        aspectRatio: cropRatio,
        compressQuality: quality, // later handle
        maxWidth: width,
        maxHeight: height,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Cropper',
            toolbarColor: application.theme.primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Cropper',
            minimumAspectRatio: 1.0,
          ),
        ],
      );
      if ((croppedFile != null) && croppedFile.path.isNotEmpty) {
        cropFile = File(croppedFile.path);
      }
    } catch (e, st) {
      handleError(e, st);
    }

    int size = await cropFile?.length() ?? 0;
    logger.i('MediaPicker - _cropImage - size:${Format.flowSize(size.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - path:${cropFile?.path}');
    return cropFile;
  }

  static Future<File?> compressImageBySize(File? original, {String? savePath, int maxSize = 0, int bestSize = 0, bool force = false, bool toast = false}) async {
    if (original == null) return null;
    bool isGif = (mime(original.path)?.indexOf('image/gif') ?? -1) >= 0;
    // size
    bool maxEnable = maxSize > 0;
    bool bestEnable = bestSize > 0;
    int originalSize = await original.length();
    if (!maxEnable && !bestEnable) {
      logger.i('MediaPicker - _compressImage - no compress - originalSize:${Format.flowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
      return original;
    } else if (maxEnable && !bestEnable) {
      if (originalSize <= maxSize) {
        logger.i('MediaPicker - _compressImage - ok with only maxSize - originalSize:${Format.flowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${Format.flowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
        return original;
      } else if (isGif) {
        if (toast) Toast.show(Settings.locale((s) => s.file_too_big));
        return null;
      } else {
        // go compress
      }
    } else if (!maxEnable && bestEnable) {
      if (originalSize <= bestSize) {
        logger.i('MediaPicker - _compressImage - ok with only bestSize - originalSize:${Format.flowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - bestSize:${Format.flowSize(bestSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
        return original;
      } else if (isGif) {
        return original;
      } else {
        // go compress
      }
    } else if (maxEnable && bestEnable) {
      if ((originalSize <= bestSize) && (originalSize <= maxSize)) {
        logger.i('MediaPicker - _compressImage - ok with size - originalSize:${Format.flowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - bestSize:${Format.flowSize(bestSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${Format.flowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
        return original;
      } else if (isGif) {
        if (originalSize > maxSize) {
          if (toast) Toast.show(Settings.locale((s) => s.file_too_big));
          return null;
        } else {
          return original;
        }
      } else {
        // go compress
      }
    }
    logger.i('MediaPicker - _compressImage - compress:START - originalSize:${Format.flowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - bestSize:${Format.flowSize(bestSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${Format.flowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');

    // filePath
    String fileExt = Path.getFileExt(original, FileHelper.DEFAULT_IMAGE_EXT);
    String compressPath = savePath ?? (await Path.getRandomFile(null, DirType.cache, fileExt: fileExt));
    // format
    CompressFormat? format;
    if (compressPath.toLowerCase().endsWith(".jpg") || compressPath.toLowerCase().endsWith(".jpeg")) {
      format = CompressFormat.jpeg;
    } else if (compressPath.toLowerCase().endsWith(".png")) {
      format = CompressFormat.png;
    } else if (compressPath.toLowerCase().endsWith(".heic")) {
      format = CompressFormat.heic;
    } else if (compressPath.toLowerCase().endsWith(".webp")) {
      format = CompressFormat.webp;
    }
    if (format == null) {
      logger.e('MediaPicker - _compressImage - compress:FAIL - CompressFormatError - compressPath:$compressPath');
      return original;
    }

    // compress
    File? compressFile;
    int compressSize = 0;
    try {
      List<int> qualityItems = force ? [20, 10, 5] : [70, 30, 15];
      List<int> widthItems = force ? [320, 32, 4] : [1920, 960, 480];
      List<int> heightItems = force ? [180, 18, 2] : [1080, 540, 270];
      for (var i = 0; i < qualityItems.length; i++) {
        int compressQuality = qualityItems[i];
        int compressWidth = widthItems[i];
        int compressHeight = heightItems[i];
        compressFile = await FlutterImageCompress.compressAndGetFile(
          original.absolute.path,
          compressPath,
          quality: compressQuality,
          minWidth: compressWidth,
          minHeight: compressHeight,
          autoCorrectionAngle: true,
          numberOfRetries: 3,
          format: format,
          keepExif: false, // true -> ios error
        );
        compressSize = await compressFile?.length() ?? 0;
        logger.d('MediaPicker - _compressImage - compress:OK - tryTimes:${i + 1} - quality:$compressQuality - compressSize:${Format.flowSize(compressSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - originalSize:${Format.flowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - bestSize:${Format.flowSize(bestSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${Format.flowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
        if (compressSize <= bestSize) break;
      }
    } catch (e, st) {
      handleError(e, st);
    }

    if (compressSize > maxSize) {
      logger.w('MediaPicker - _compressImage - compress:BREAK - compressSize:${Format.flowSize(compressSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - originalSize:${Format.flowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - bestSize:${Format.flowSize(bestSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${Format.flowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - format:$format - path:${compressFile?.path}');
      if (toast) Toast.show(Settings.locale((s) => s.file_too_big));
      return null;
    }
    logger.i('MediaPicker - _compressImage - compress:END - compressSize:${Format.flowSize(compressSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - originalSize:${Format.flowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - bestSize:${Format.flowSize(bestSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${Format.flowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - format:$format - path:${compressFile?.path}');
    return compressFile;
  }

  /*static Future<Size?> getImageSize(File file) async {
    var decodedImage = await decodeImageFromList(file.readAsBytesSync());
    // return {"width": decodedImage.width, "width": decodedImage.width};
    int? width, height;
    Image image = new Image.file(file);
    Completer completer = new Completer();
    image.image.resolve(new ImageConfiguration()).addListener(ImageStreamListener((ImageInfo info, bool _) {
      width = info.image.width;
      height = info.image.height;
      completer.complete();
    }));
    await completer.future;
    if (width != null && height != null) {
      return Size(width?.toDouble(), height?.toDouble());
    }
    return null;
  }*/

  static Future<Map<String, dynamic>?> getVideoThumbnail(String filePath, String savePath, {int quality = 20, int maxWidth = 100}) async {
    if (filePath.isEmpty || savePath.isEmpty) return null;
    // thumbnail
    Uint8List? imgBytes;
    try {
      imgBytes = await VideoThumbnail.VideoThumbnail.thumbnailData(
        video: filePath,
        imageFormat: VideoThumbnail.ImageFormat.JPEG,
        maxWidth: maxWidth, // specify the width of the thumbnail, let the height auto-scaled to keep the source aspect ratio
        quality: quality,
      );
    } catch (e, st) {
      handleError(e, st);
    }
    if (imgBytes == null || imgBytes.isEmpty) {
      logger.w('MediaPicker - getVideoThumbnail - fail - filePath:$filePath');
      return null;
    }
    // save
    File saveFile = File(savePath);
    if (!await saveFile.exists()) {
      await saveFile.create(recursive: true);
    } else {
      await saveFile.delete();
      await saveFile.create(recursive: true);
    }
    saveFile = await saveFile.writeAsBytes(imgBytes);
    int size = await saveFile.length();
    return {"path": savePath, "file": saveFile, "size": size};
  }

  static Future<bool> _isPermissionOK(ImageSource source) async {
    // AssetPicker.permissionCheck();
    Permission permission;
    if (source == ImageSource.camera) {
      permission = Permission.camera;
    } else if (source == ImageSource.gallery) {
      if (Platform.isIOS) {
        int osVersion = int.tryParse(Settings.deviceVersion) ?? 0;
        if (osVersion >= 14) {
          permission = Permission.photos;
        } else {
          permission = Permission.mediaLibrary;
        }
      } else {
        permission = Permission.mediaLibrary;
        // return true;
      }
    } else {
      return false;
    }
    PermissionStatus permissionStatus = await permission.request();
    if (permissionStatus == PermissionStatus.permanentlyDenied) {
      openAppSettings();
      return false;
    } else if (permissionStatus == PermissionStatus.denied || permissionStatus == PermissionStatus.restricted) {
      return false;
    }
    return true;
  }

  static ThemeData _getTheme() {
    ThemeData theme = AssetPicker.themeData(application.theme.primaryColor);
    theme = ThemeData.dark().copyWith(
      primaryColor: theme.primaryColor,
      primaryColorLight: theme.primaryColorLight,
      primaryColorDark: theme.primaryColorDark,
      canvasColor: Colors.black87,
      scaffoldBackgroundColor: theme.scaffoldBackgroundColor,
      // bottomAppBarColor: theme.bottomAppBarColor,
      cardColor: theme.cardColor,
      highlightColor: theme.highlightColor,
      // toggleableActiveColor: theme.toggleableActiveColor,
      textSelectionTheme: theme.textSelectionTheme,
      indicatorColor: theme.indicatorColor,
      appBarTheme: theme.appBarTheme,
      buttonTheme: theme.buttonTheme,
      colorScheme: theme.colorScheme,
    );
    return theme;
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime_type/mime_type.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter_luban/flutter_luban.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class MediaPicker {
  static Future<List<Map<String, dynamic>>> pickCommons(
    List<String> savePaths, {
    bool compressImage = false,
    bool compressVideo = false,
    int? maxSize,
  }) async {
    // maxNum
    int maxNum = savePaths.length;
    if (maxNum > 9) maxNum = 9;
    if (maxNum < 1) return [];

    // permission, == AssetPicker.permissionCheck();
    bool permissionOK = await _isPermissionOK(ImageSource.gallery);
    if (!permissionOK) return [];

    // pick
    List<AssetEntity>? pickedResults;
    try {
      pickedResults = await AssetPicker.pickAssets(
        Global.appContext,
        pickerConfig: AssetPickerConfig(
          themeColor: application.theme.primaryColor,
          requestType: RequestType.common,
          maxAssets: maxNum,
          gridCount: 4,
          pageSize: 32,
        ),
      );
    } catch (e) {
      handleError(e);
    }
    if (pickedResults == null || pickedResults.isEmpty) {
      logger.w("MediaPicker - pickCommons - pickedResults = null");
      return [];
    }

    // result
    List<Map<String, dynamic>> pickedMaps = [];
    for (var i = 0; i < pickedResults.length; i++) {
      AssetEntity entity = pickedResults[i];
      // exist
      File? file = (await entity.originFile) ?? (await entity.loadFile(isOrigin: true));
      if (file == null || file.path.isEmpty) {
        logger.w("MediaPicker - pickCommons - pickedResults originFile = null");
        continue;
      }
      // ext
      String ext = "";
      List<String>? splits = entity.mimeType?.split("/");
      if (splits != null && splits.length > 1) {
        ext = splits[splits.length - 1];
      }
      // compress
      bool isImage = entity.type == AssetType.image;
      bool isVideo = entity.type == AssetType.video;
      try {
        if (isImage && compressImage) {
          // TODO:GG compress
        } else if (isVideo && compressVideo) {
          // TODO:GG compress
        } else {
          // TODO:GG original
        }
      } catch (e) {
        handleError(e);
      }
      // size
      int size = file.lengthSync();
      if (maxSize != null && maxSize > 0) {
        if (size >= maxSize) {
          Toast.show(Global.locale((s) => s.file_too_big));
          continue;
        }
      }
      String savePath;
      // save
      if (savePaths.length > i) {
        savePath = Path.joinFileExt(File(savePaths[i]).path, ext);
        File saveFile = File(savePath);
        if (!await saveFile.exists()) {
          await saveFile.create(recursive: true);
        }
        saveFile = await file.copy(savePath);
      } else {
        savePath = file.absolute.path;
      }
      // map
      if (savePath.isNotEmpty) {
        Map<String, dynamic> params = {
          "path": savePath,
          "size": size,
          "fileExt": ext.isEmpty ? null : ext,
          "mimeType": entity.mimeType,
          "width": entity.orientatedWidth,
          "height": entity.orientatedHeight,
        };
        if (isVideo) {
          params.addAll({
            "duration": entity.duration,
            // "thumbnail": await entity.thumbnailData, // TODO:GG 后续再加
          });
        }
        pickedMaps.add(params);
      }
      logger.i("MediaPicker - pickCommons - picked success - entity${entity.toString()}");
    }
    return pickedMaps;
  }

  // TODO:GG 适配拍视频（压缩?）注意返回格式
  static Future<File?> takeCommon({
    CropStyle? cropStyle,
    CropAspectRatio? cropRatio,
    int? bestSize,
    int? maxSize,
    String? returnPath,
  }) async {
    // pick
    XFile? pickedResult;
    try {
      pickedResult = await ImagePicker().pickImage(source: ImageSource.camera); // imageQuality: compressQuality  -> ios no enable
    } catch (e) {
      handleError(e);
    }
    if (pickedResult == null || pickedResult.path.isEmpty) {
      logger.w("MediaPicker - _pickImageBySystem - pickedResult = null");
      return null;
    }

    // convert
    File? pickedFile = File(pickedResult.path);
    logger.i("MediaPicker - _pickImageBySystem - picked - path:${pickedFile.path}");
    pickedFile.length().then((value) {
      logger.i('MediaPicker - _pickImageBySystem - picked - size:${Format.flowSize(value.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
    });

    // crop
    pickedFile = await _cropImage(pickedFile, cropStyle, cropRatio: cropRatio);
    if (pickedFile == null) {
      logger.w('MediaPicker - _pickImageBySystem - croppedFile = null');
      return null;
    }

    // compress
    pickedFile = await _compressImageBySize(pickedFile, maxSize: maxSize ?? 0, bestSize: bestSize ?? 0, toast: true);
    if (pickedFile == null) {
      logger.w('MediaPicker - _pickImageBySystem - compress = null');
      return null;
    }

    // save
    String fileExt = Path.getFileExt(pickedFile, 'jpg');
    if (returnPath == null || returnPath.isEmpty) {
      returnPath = await Path.getRandomFile(null, DirType.cache, fileExt: fileExt);
    } else {
      returnPath = Path.joinFileExt(returnPath, fileExt);
    }
    File returnFile = File(returnPath);
    if (!await returnFile.exists()) {
      await returnFile.create(recursive: true);
    }
    returnFile = await pickedFile.copy(returnPath);

    logger.i('MediaPicker - takeImage - return - path:${returnFile.path}');
    return returnFile;
  }

  // TODO:GG 还需要压缩码(目前只用于头像)？
  static Future<File?> pickImage({
    CropStyle? cropStyle,
    CropAspectRatio? cropRatio,
    int? bestSize,
    int? maxSize,
    String? returnPath,
  }) async {
    // permission, same with AssetPicker.permissionCheck();
    bool permissionOK = await _isPermissionOK(ImageSource.gallery);
    if (!permissionOK) return null;

    // pick
    List<AssetEntity>? pickedResults;
    try {
      pickedResults = await AssetPicker.pickAssets(
        Global.appContext,
        pickerConfig: AssetPickerConfig(
          themeColor: application.theme.primaryColor,
          requestType: RequestType.image,
          maxAssets: 1,
          gridCount: 3,
          pageSize: 30,
        ),
      );
    } catch (e) {
      handleError(e);
    }
    if (pickedResults == null || pickedResults.isEmpty) {
      logger.w("MediaPicker - pickImage - pickedResults = null");
      return null;
    }

    // convert
    File? pickedFile = (await pickedResults[0].originFile) ?? (await pickedResults[0].loadFile(isOrigin: false));
    if (pickedFile == null || pickedFile.path.isEmpty) {
      logger.w("MediaPicker - pickImage - pickedFile = null");
      return null;
    }
    logger.i("MediaPicker - pickImage - picked - path:${pickedFile.path}");
    pickedFile.length().then((value) {
      logger.i('MediaPicker - pickImage - picked - size:${Format.flowSize(value.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
    });

    // crop
    pickedFile = await _cropImage(pickedFile, cropStyle, cropRatio: cropRatio);
    if (pickedFile == null) {
      logger.w('MediaPicker - pickImage - croppedFile = null');
      return null;
    }

    // compress
    pickedFile = await _compressImageBySize(pickedFile, maxSize: maxSize ?? 0, bestSize: bestSize ?? 0, toast: true);
    if (pickedFile == null) {
      logger.w('MediaPicker - pickImage - compress = null');
      return null;
    }

    // save
    String fileExt = Path.getFileExt(pickedFile, 'jpg');
    if (returnPath == null || returnPath.isEmpty) {
      returnPath = await Path.getRandomFile(null, DirType.cache, fileExt: fileExt);
    } else {
      returnPath = Path.joinFileExt(returnPath, fileExt);
    }
    File returnFile = File(returnPath);
    if (!await returnFile.exists()) {
      await returnFile.create(recursive: true);
    }
    returnFile = await pickedFile.copy(returnPath);

    logger.i('MediaPicker - pickImage - return - path:${returnFile.path}');
    return returnFile;
  }

  static Future<File?> _cropImage(File? original, CropStyle? cropStyle, {CropAspectRatio? cropRatio}) async {
    if (original == null) return null;
    if (cropStyle == null) return original;
    // gif
    bool isGif = (mime(original.path)?.indexOf('image/gif') ?? -1) >= 0;
    if (isGif) return original;
    // crop
    File? cropFile;
    try {
      cropFile = await ImageCropper.cropImage(
        sourcePath: original.absolute.path,
        cropStyle: cropStyle,
        aspectRatio: cropRatio,
        compressQuality: 100, // later handle
        maxWidth: null,
        maxHeight: null,
        iosUiSettings: IOSUiSettings(
          title: 'Cropper',
          minimumAspectRatio: 1.0,
        ),
        androidUiSettings: AndroidUiSettings(
          toolbarTitle: 'Cropper',
          toolbarColor: application.theme.primaryColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
      );
    } catch (e) {
      handleError(e);
    }

    int size = await cropFile?.length() ?? 0;
    logger.i('MediaPicker - _cropImage - size:${Format.flowSize(size.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - path:${cropFile?.path}');
    return cropFile;
  }

  static Future<File?> _compressImageBySize(File? original, {int maxSize = 0, int bestSize = 0, bool toast = false}) async {
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
        if (toast) Toast.show(Global.locale((s) => s.file_too_big));
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
          if (toast) Toast.show(Global.locale((s) => s.file_too_big));
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
    String fileExt = Path.getFileExt(original, 'jpg');
    String compressPath = await Path.getRandomFile(null, DirType.cache, fileExt: fileExt);
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
      logger.w('MediaPicker - _compressImage - compress:FAIL - CompressFormatError - fileExt:$fileExt - compressPath:$compressPath');
      return original;
    }

    // compress
    File? compressFile;
    int compressSize = 0;
    try {
      int offsetQuality = 20;
      int tryTimes = 0;
      int compressQuality = 100;
      while (compressQuality > offsetQuality) {
        tryTimes++;
        compressQuality = 90 - tryTimes * offsetQuality;
        compressFile = await FlutterImageCompress.compressAndGetFile(
          original.absolute.path,
          compressPath,
          quality: compressQuality,
          autoCorrectionAngle: true,
          numberOfRetries: 3,
          format: format,
          keepExif: false, // true -> ios error
        );
        compressSize = await compressFile?.length() ?? 0;
        logger.d('MediaPicker - _compressImage - compress:OK - tryTimes:$tryTimes - quality:$compressQuality - compressSize:${Format.flowSize(compressSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - originalSize:${Format.flowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - bestSize:${Format.flowSize(bestSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${Format.flowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
        if (compressSize <= bestSize) break;
      }
    } catch (e) {
      handleError(e);
    }

    if (compressSize > maxSize) {
      logger.w('MediaPicker - _compressImage - compress:BREAK - compressSize:${Format.flowSize(compressSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - originalSize:${Format.flowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - bestSize:${Format.flowSize(bestSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${Format.flowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - format:$format - path:${compressFile?.path}');
      if (toast) Toast.show(Global.locale((s) => s.file_too_big));
      return null;
    }
    logger.i('MediaPicker - _compressImage - compress:END - compressSize:${Format.flowSize(compressSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - originalSize:${Format.flowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - bestSize:${Format.flowSize(bestSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${Format.flowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - format:$format - path:${compressFile?.path}');
    return compressFile;
  }

  static Future<bool> _isPermissionOK(ImageSource source) async {
    Permission permission;
    if (source == ImageSource.camera) {
      permission = Permission.camera;
    } else if (source == ImageSource.gallery) {
      if (Platform.isIOS) {
        int osVersion = int.tryParse(Global.deviceVersion) ?? 0;
        if (osVersion >= 14) {
          permission = Permission.photos;
        } else {
          permission = Permission.mediaLibrary;
        }
      } else {
        permission = Permission.mediaLibrary;
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
}

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
  static Future<File?> pickVideo({
    ImageSource source = ImageSource.gallery,
    int? maxSize,
    Duration? maxDuration,
    String? returnPath,
  }) async {
    // await ImagePicker().pickVideo(source: source, maxDuration: maxDuration);
    return null;
  }

  // TODO:GG bottomMenu选这个
  static Future<List<File>> pickImages(
    int maxNum, {
    int? bestSize,
    int? maxSize,
    List<String> returnPaths = const [],
  }) async {
    if (maxNum < 1) maxNum = 1;
    if (maxNum > 9) maxNum = 9;

    // permission, same with AssetPicker.permissionCheck();
    bool permissionOK = await _isPermissionOK(ImageSource.gallery);
    if (!permissionOK) return [];

    // pick
    List<AssetEntity>? pickedResults;
    try {
      pickedResults = await AssetPicker.pickAssets(
        Global.appContext,
        pickerConfig: AssetPickerConfig(
          themeColor: application.theme.primaryColor,
          requestType: RequestType.image,
          maxAssets: maxNum,
          gridCount: 3,
          pageSize: 30,
        ),
      );
    } catch (e) {
      handleError(e);
    }
    if (pickedResults == null || pickedResults.isEmpty) {
      logger.w("MediaPicker - pickImages - pickedResults = null");
      return [];
    }

    // convert
    List<File> pickFiles = [];
    for (var i = 0; i < pickedResults.length; i++) {
      File? file = (await pickedResults[i].originFile) ?? (await pickedResults[i].loadFile(isOrigin: false));
      if (file != null && file.path.isNotEmpty) {
        logger.i("MediaPicker - pickImages - picked - path:${file.path}");
        file.length().then((value) {
          logger.i('MediaPicker - pickImages - picked - index:$i - size:${formatFlowSize(value.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
        });
        pickFiles.add(file);
      }
    }
    if (pickFiles.isEmpty) {
      logger.w("MediaPicker - pickImages - pickedFiles = null");
      return [];
    }

    // compress
    List<File> compressFiles = [];
    for (var i = 0; i < pickFiles.length; i++) {
      File? file = await _compressImage(pickFiles[i], maxSize: maxSize ?? 0, bestSize: bestSize ?? 0, toast: true);
      if (file != null) {
        logger.i("MediaPicker - pickImages - compress success - index:$i");
        compressFiles.add(file);
      } else {
        logger.w("MediaPicker - pickImages - compress fail - index:$i");
      }
    }
    if (compressFiles.isEmpty) {
      logger.w('MediaPicker - pickImages - compress = null');
      return [];
    }

    // save
    List<File> returnFiles = [];
    for (var i = 0; i < compressFiles.length; i++) {
      String? returnPath;
      if (returnPaths.length > i) returnPath = returnPaths[i];
      if (returnPath == null || returnPath.isEmpty) {
        String fileExt = Path.getFileExt(compressFiles[i], 'jpeg');
        returnPath = await Path.getRandomFile(null, SubDirType.cache, fileExt: fileExt);
      }
      File returnFile = File(returnPath);
      if (!await returnFile.exists()) {
        await returnFile.create(recursive: true);
      }
      returnFile = await compressFiles[i].copy(returnPath);
      returnFiles.add(returnFile);
      logger.i('MediaPicker - pickImages - return - index:$i - path:${returnFile.path}');
    }
    return returnFiles;
  }

  static Future<File?> pickImage({
    ImageSource source = ImageSource.gallery,
    CropStyle? cropStyle,
    CropAspectRatio? cropRatio,
    int? bestSize,
    int? maxSize,
    String? returnPath,
  }) async {
    // permission, same with AssetPicker.permissionCheck();
    bool permissionOK = await _isPermissionOK(source);
    if (!permissionOK) return null;

    // TODO:GG 替换成flutter_wechat_camera_picker???
    // take picture
    // if (source == ImageSource.camera) {
    //   return _pickImageBySystem(
    //     source: source,
    //     cropStyle: cropStyle,
    //     cropRatio: cropRatio,
    //     bestSize: bestSize,
    //     maxSize: maxSize,
    //     returnPath: returnPath,
    //   );
    // }

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
      logger.i('MediaPicker - pickImage - picked - size:${formatFlowSize(value.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
    });

    // crop
    pickedFile = await _cropImage(pickedFile, cropStyle, cropRatio: cropRatio);
    if (pickedFile == null) {
      logger.w('MediaPicker - pickImage - croppedFile = null');
      return null;
    }

    // compress
    pickedFile = await _compressImage(pickedFile, maxSize: maxSize ?? 0, bestSize: bestSize ?? 0, toast: true);
    if (pickedFile == null) {
      logger.w('MediaPicker - pickImage - compress = null');
      return null;
    }

    // save
    if (returnPath == null || returnPath.isEmpty) {
      String fileExt = Path.getFileExt(pickedFile, 'jpeg');
      returnPath = await Path.getRandomFile(null, SubDirType.cache, fileExt: fileExt);
    }
    File returnFile = File(returnPath);
    if (!await returnFile.exists()) {
      await returnFile.create(recursive: true);
    }
    returnFile = await pickedFile.copy(returnPath);

    logger.i('MediaPicker - pickImage - return - path:${returnFile.path}');
    return returnFile;
  }

  static Future<File?> _pickImageBySystem({
    ImageSource source = ImageSource.gallery,
    CropStyle? cropStyle,
    CropAspectRatio? cropRatio,
    int bestSize = 0,
    int maxSize = 0,
    String? returnPath,
  }) async {
    // pick
    XFile? pickedResult;
    try {
      pickedResult = await ImagePicker().pickImage(source: source); // imageQuality: compressQuality  -> ios no enable
    } catch (e) {
      handleError(e);
    }
    if (pickedResult == null || pickedResult.path.isEmpty) {
      logger.w("MediaPicker - _pickImageBySystem - pickedResult = null");
      return null;
    }
    File pickedFile = File(pickedResult.path);
    logger.i("MediaPicker - _pickImageBySystem - picked - path:${pickedFile.path}");
    pickedFile.length().then((value) {
      logger.i('MediaPicker - _pickImageBySystem - picked - size:${formatFlowSize(value.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
    });

    // crop
    File? croppedFile = await _cropImage(pickedFile, cropStyle, cropRatio: cropRatio);
    if (croppedFile == null) {
      logger.w('MediaPicker - _pickImageBySystem - croppedFile = null');
      return null;
    }

    // compress
    File? compressFile = await _compressImage(croppedFile, maxSize: maxSize, bestSize: bestSize, toast: true);
    if (compressFile == null) {
      logger.w('MediaPicker - _pickImageBySystem - compress = null');
      return null;
    }

    // save
    File returnFile;
    if (returnPath != null && returnPath.isNotEmpty) {
      returnFile = File(returnPath);
      if (!await returnFile.exists()) {
        await returnFile.create(recursive: true);
      }
      returnFile = await compressFile.copy(returnPath);
    } else {
      String fileExt = Path.getFileExt(pickedFile, 'jpeg');
      String randomPath = await Path.getRandomFile(null, SubDirType.cache, fileExt: fileExt);
      returnFile = File(randomPath);
      if (!await returnFile.exists()) {
        await returnFile.create(recursive: true);
      }
      returnFile = await compressFile.copy(randomPath);
    }
    logger.i('MediaPicker - _pickImageBySystem - return - path:${returnFile.path}');
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
    logger.i('MediaPicker - _cropImage - size:${formatFlowSize(size.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - path:${cropFile?.path}');
    return cropFile;
  }

  static Future<File?> _compressImage(File? original, {int maxSize = 0, int bestSize = 0, bool toast = false}) async {
    if (original == null) return null;
    bool isGif = (mime(original.path)?.indexOf('image/gif') ?? -1) >= 0;
    // size
    bool maxEnable = maxSize > 0;
    bool bestEnable = bestSize > 0;
    int originalSize = await original.length();
    if (!maxEnable && !bestEnable) {
      logger.i('MediaPicker - _compressImage - no compress - originalSize:${formatFlowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
      return original;
    } else if (maxEnable && !bestEnable) {
      if (originalSize <= maxSize) {
        logger.i('MediaPicker - _compressImage - ok with only maxSize - originalSize:${formatFlowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${formatFlowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
        return original;
      } else if (isGif) {
        if (toast) Toast.show(Global.locale((s) => s.file_too_big));
        return null;
      } else {
        // go compress
      }
    } else if (!maxEnable && bestEnable) {
      if (originalSize <= bestSize) {
        logger.i('MediaPicker - _compressImage - ok with only bestSize - originalSize:${formatFlowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - bestSize:${formatFlowSize(bestSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
        return original;
      } else if (isGif) {
        return original;
      } else {
        // go compress
      }
    } else if (maxEnable && bestEnable) {
      if ((originalSize <= bestSize) && (originalSize <= maxSize)) {
        logger.i('MediaPicker - _compressImage - ok with size - originalSize:${formatFlowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - bestSize:${formatFlowSize(bestSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${formatFlowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
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
    logger.i('MediaPicker - _compressImage - compress:START - originalSize:${formatFlowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - bestSize:${formatFlowSize(bestSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${formatFlowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');

    // filePath
    String fileExt = Path.getFileExt(original, 'jpeg');
    String compressPath = await Path.getRandomFile(null, SubDirType.cache, fileExt: fileExt);
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
        logger.d('MediaPicker - _compressImage - compress:OK - tryTimes:$tryTimes - quality:$compressQuality - compressSize:${formatFlowSize(compressSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - originalSize:${formatFlowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - bestSize:${formatFlowSize(bestSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${formatFlowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
        if (compressSize <= bestSize) break;
      }
    } catch (e) {
      handleError(e);
    }

    if (compressSize > maxSize) {
      logger.w('MediaPicker - _compressImage - compress:BREAK - compressSize:${formatFlowSize(compressSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - originalSize:${formatFlowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - bestSize:${formatFlowSize(bestSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${formatFlowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - format:$format - path:${compressFile?.path}');
      if (toast) Toast.show(Global.locale((s) => s.file_too_big));
      return null;
    }
    logger.i('MediaPicker - _compressImage - compress:END - compressSize:${formatFlowSize(compressSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - originalSize:${formatFlowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - bestSize:${formatFlowSize(bestSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${formatFlowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - format:$format - path:${compressFile?.path}');
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

// TODO:GG 替换成LuBan吗？
// File? compressFile;
// String compressDirPath = await Path.getDir(null, SubDirType.cache);
// CompressObject compressObject = CompressObject(
//   imageFile: original,
//   path: compressDirPath,
//   quality: compressQuality, // first compress quality, default 80
//   step: 8, // compress quality step, The bigger the fast, Smaller is more accurate, default 6
//   mode: CompressMode.LARGE2SMALL, //default AUTO
// );
// try {
//   String? returnPath = await Luban.compressImage(compressObject);
//   compressFile = (returnPath?.isNotEmpty == true) ? File(returnPath!) : null;
// } catch (e) {
//   handleError(e);
// }
// if (compressFile == null || !compressFile.existsSync()) {
//   logger.i('MediaPicker - _compressImage - compress:FAIL - compressQuality:$compressQuality - path:${compressFile?.path}');
//   return original;
// }
// size = await compressFile.length();
// logger.i('MediaPicker - _compressImage - compress:OK - compressQuality:$compressQuality - size:${formatFlowSize(size.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - path:${compressFile.path}');

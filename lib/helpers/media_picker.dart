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
// import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class MediaType {
  static const image = 0;
  static const audio = 1;
  static const video = 2;
  static const common = 3;
}

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

  static Future<File?> pickImage({
    ImageSource source = ImageSource.gallery,
    CropStyle? cropStyle,
    CropAspectRatio? cropRatio,
    int? maxSize,
    String? returnPath,
  }) async {
    // if (source == ImageSource.camera) {
    return _pickImageBySystem(
      source: source,
      cropStyle: cropStyle,
      cropRatio: cropRatio,
      maxSize: maxSize,
      returnPath: returnPath,
    );
    // }
    // // permission
    // // PermissionStatus permissionLibrary = await Permission.mediaLibrary.request();
    // // if (permissionLibrary != PermissionStatus.granted) {
    // //   return null;
    // // }
    // PermissionStatus permissionCamera = await Permission.camera.request();
    // if (permissionCamera != PermissionStatus.granted) {
    //   return null;
    // }
    // // pick
    // RequestType requestType = RequestType.common;
    // if (mediaType == MediaType.video) {
    //   requestType = RequestType.video;
    // } else if (mediaType == MediaType.audio) {
    //   requestType = RequestType.audio;
    // } else if (mediaType == MediaType.image) {
    //   requestType = RequestType.image;
    // } else if (mediaType == MediaType.common) {
    //   requestType = RequestType.common;
    // }
    // List<AssetEntity>? pickedResults = await AssetPicker.pickAssets(
    //   Global.appContext,
    //   requestType: requestType,
    //   maxAssets: 1,
    //   themeColor: application.theme.primaryColor,
    //   gridCount: 3,
    //   pageSize: 60,
    // );
    // if (pickedResults == null || pickedResults.isEmpty) {
    //   logger.w("MediaPicker - pickSingle - pickedResults = null"); // eg:/data/user/0/org.nkn.mobile.app.debug/cache/image_picker3336694179441112013.jpg
    //   return null;
    // }
    //
    // // convert
    // File? pickedFile = (await pickedResults[0].originFile) ?? (await pickedResults[0].loadFile(isOrigin: false));
    // if (pickedFile == null || pickedFile.path.isEmpty) {
    //   logger.w("MediaPicker - pickSingle - pickedFile = null"); // eg:/data/user/0/org.nkn.mobile.app.debug/cache/image_picker3336694179441112013.jpg
    //   return null;
    // }
    // logger.i("MediaPicker - pickSingle - picked - path:${pickedFile.path}"); // eg:/data/user/0/org.nkn.mobile.app.debug/cache/image_picker3336694179441112013.jpg
    // pickedFile.length().then((value) {
    //   logger.i('MediaPicker - pickSingle - picked - size:${formatFlowSize(value.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
    // });
    //
    // // crop
    // File? croppedFile = await _cropFile(pickedFile, mediaType, cropStyle, cropRatio);
    // if (croppedFile == null) {
    //   logger.w('MediaPicker - pickSingle - croppedFile = null}');
    //   return null;
    // }
    //
    // // compress
    // File? compressFile = await _compressFile(croppedFile, mediaType, compressQuality);
    // if (compressFile == null) {
    //   logger.w('MediaPicker - pickSingle - compress = null}');
    //   return null;
    // }
    //
    // // return
    // File returnFile;
    // if (returnPath != null && returnPath.isNotEmpty) {
    //   returnFile = File(returnPath);
    //   if (!await returnFile.exists()) {
    //     await returnFile.create(recursive: true);
    //   }
    //   returnFile = await compressFile.copy(returnPath);
    // } else {
    //   String? fileExt = Path.getFileExt(pickedFile);
    //   if (fileExt == null || fileExt.isEmpty) {
    //     switch (mediaType) {
    //       case MediaType.image:
    //         fileExt = 'jpeg';
    //         break;
    //       case MediaType.audio:
    //         fileExt = 'mp3';
    //         break;
    //       case MediaType.video:
    //         fileExt = 'mp4';
    //         break;
    //     }
    //   }
    //   String randomPath = await Path.getCacheFile("cache", fileExt: fileExt);
    //   returnFile = File(randomPath);
    //   if (!await returnFile.exists()) {
    //     await returnFile.create(recursive: true);
    //   }
    //   returnFile = await compressFile.copy(randomPath);
    // }
    // logger.i('MediaPicker - pickSingle - return - path:${returnFile.path}');
    // return returnFile;
  }

  static Future<File?> _pickImageBySystem({
    ImageSource source = ImageSource.gallery,
    CropStyle? cropStyle,
    CropAspectRatio? cropRatio,
    int? maxSize,
    String? returnPath,
  }) async {
    // permission
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
      return null;
    }
    PermissionStatus permissionStatus = await permission.request();
    if (permissionStatus == PermissionStatus.permanentlyDenied) {
      openAppSettings();
      return null;
    } else if (permissionStatus == PermissionStatus.denied || permissionStatus == PermissionStatus.restricted) {
      return null;
    }

    // pick
    XFile? pickedResult;
    try {
      pickedResult = await ImagePicker().pickImage(source: source); // imageQuality: compressQuality  -> ios no enable
    } catch (e) {
      handleError(e);
    }
    if (pickedResult == null || pickedResult.path.isEmpty) {
      logger.w("MediaPicker - _pickImageBySystem - pickedResult = null"); // eg:/data/user/0/org.nkn.mobile.app.debug/cache/image_picker3336694179441112013.jpg
      return null;
    }
    File pickedFile = File(pickedResult.path);
    logger.i("MediaPicker - _pickImageBySystem - picked - path:${pickedFile.path}"); // eg:/data/user/0/org.nkn.mobile.app.debug/cache/image_picker3336694179441112013.jpg
    pickedFile.length().then((value) {
      logger.i('MediaPicker - _pickImageBySystem - picked - size:${formatFlowSize(value.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
    });

    // crop
    File? croppedFile = await _cropImage(pickedFile, cropStyle, cropRatio);
    if (croppedFile == null) {
      logger.w('MediaPicker - _pickImageBySystem - croppedFile = null');
      return null;
    }

    // compress
    File? compressFile = await _compressImage(croppedFile, maxSize);
    if (compressFile == null) {
      logger.w('MediaPicker - _pickImageBySystem - compress = null');
      return null;
    }

    // return
    File returnFile;
    if (returnPath != null && returnPath.isNotEmpty) {
      returnFile = File(returnPath);
      if (!await returnFile.exists()) {
        await returnFile.create(recursive: true);
      }
      returnFile = await compressFile.copy(returnPath);
    } else {
      String? fileExt = Path.getFileExt(pickedFile);
      if (fileExt == null || fileExt.isEmpty) fileExt = 'jpeg';
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

  static Future<File?> _cropImage(File? original, CropStyle? cropStyle, CropAspectRatio? cropRatio) async {
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
        // maxWidth: 300,
        // maxHeight: 300,
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

  static Future<File?> _compressImage(File? original, int? maxSize) async {
    if (original == null) return null;
    // maxSize
    if (maxSize == null) return original;
    int originalSize = await original.length();
    if (originalSize <= maxSize) {
      logger.i('MediaPicker - _compressImage - size ok - originalSize:${formatFlowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${formatFlowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
      return original;
    }
    // gif
    bool isGif = (mime(original.path)?.indexOf('image/gif') ?? -1) >= 0;
    if (isGif) {
      logger.w('MediaPicker - _compressImage - gif over - originalSize:${formatFlowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${formatFlowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
      Toast.show(Global.locale((s) => s.file_too_big));
      return null;
    }
    logger.i('MediaPicker - _compressImage - compress:START - originalSize:${formatFlowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${formatFlowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');

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

    // filePath
    String? fileExt = Path.getFileExt(original);
    if (fileExt == null || fileExt.isEmpty) fileExt = 'jpeg';
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
          // minWidth: 300,
          // minHeight: 300,
          // keepExif: true,
        );
        compressSize = await compressFile?.length() ?? 0;
        logger.d('MediaPicker - _compressImage - compress:END - tryTimes:$tryTimes - quality:$compressQuality - compressSize:${formatFlowSize(compressSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - originalSize:${formatFlowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${formatFlowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
        if (compressSize <= maxSize) break;
      }
    } catch (e) {
      handleError(e);
    }

    if (compressSize <= maxSize) {
      logger.i('MediaPicker - _compressImage - compress:OK - compressSize:${formatFlowSize(compressSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - originalSize:${formatFlowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${formatFlowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - format:$format - path:${compressFile?.path}');
    } else {
      logger.w('MediaPicker - _compressImage - compress:OVER - compressSize:${formatFlowSize(compressSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - originalSize:${formatFlowSize(originalSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - maxSize:${formatFlowSize(maxSize.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])} - format:$format - path:${compressFile?.path}');
      Toast.show(Global.locale((s) => s.file_too_big));
      return null;
    }
    return compressFile;
  }
}

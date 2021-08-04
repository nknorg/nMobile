import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime_type/mime_type.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class MediaType {
  static const int image = 0;
  static const int audio = 1;
  static const int video = 2;
  static const int common = 3;
}

class MediaPicker {
  static Future<File?> pickSingle({
    ImageSource source = ImageSource.gallery,
    int mediaType = MediaType.image,
    CropStyle? cropStyle,
    CropAspectRatio? cropRatio,
    int compressQuality = 100,
    String? returnPath,
    Duration? maxDuration,
  }) async {
    if (source == ImageSource.camera) {
      return pickImageAndVideoBySystem(
        source: source,
        mediaType: mediaType,
        cropStyle: cropStyle,
        cropRatio: cropRatio,
        compressQuality: compressQuality,
        returnPath: returnPath,
        maxDuration: maxDuration,
      );
    }
    // permission
    // PermissionStatus permissionLibrary = await Permission.mediaLibrary.request();
    // if (permissionLibrary != PermissionStatus.granted) {
    //   return null;
    // }
    PermissionStatus permissionCamera = await Permission.camera.request();
    if (permissionCamera != PermissionStatus.granted) {
      return null;
    }
    // pick
    RequestType requestType = RequestType.common;
    if (mediaType == MediaType.video) {
      requestType = RequestType.video;
    } else if (mediaType == MediaType.audio) {
      requestType = RequestType.audio;
    } else if (mediaType == MediaType.image) {
      requestType = RequestType.image;
    } else if (mediaType == MediaType.common) {
      requestType = RequestType.common;
    }
    List<AssetEntity>? pickedResults = await AssetPicker.pickAssets(
      Global.appContext,
      requestType: requestType,
      maxAssets: 1,
      themeColor: application.theme.primaryColor,
      gridCount: 3,
      pageSize: 60,
    );
    if (pickedResults == null || pickedResults.isEmpty) {
      logger.w("MediaPicker - pickSingle - pickedResults = null"); // eg:/data/user/0/org.nkn.mobile.app.debug/cache/image_picker3336694179441112013.jpg
      return null;
    }

    // convert
    File? pickedFile = (await pickedResults[0].originFile) ?? (await pickedResults[0].loadFile(isOrigin: false));
    if (pickedFile == null || pickedFile.path.isEmpty) {
      logger.w("MediaPicker - pickSingle - pickedFile = null"); // eg:/data/user/0/org.nkn.mobile.app.debug/cache/image_picker3336694179441112013.jpg
      return null;
    }
    logger.i("MediaPicker - pickSingle - picked - path:${pickedFile.path}"); // eg:/data/user/0/org.nkn.mobile.app.debug/cache/image_picker3336694179441112013.jpg
    pickedFile.length().then((value) {
      logger.i('MediaPicker - pickSingle - picked - size:${formatFlowSize(value.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
    });

    // crop
    File? croppedFile = await _cropFile(pickedFile, mediaType, cropStyle, cropRatio);
    if (croppedFile == null) {
      logger.w('MediaPicker - pickSingle - croppedFile = null}');
      return null;
    }

    // compress
    File? compressFile = await _compressFile(croppedFile, mediaType, compressQuality);
    if (compressFile == null) {
      logger.w('MediaPicker - pickSingle - compress = null}');
      return null;
    }

    // return
    File returnFile;
    if (returnPath != null && returnPath.isNotEmpty) {
      returnFile = File(returnPath);
      if (!await returnFile.exists()) {
        returnFile.createSync(recursive: true);
      }
      returnFile = compressFile.copySync(returnPath);
    } else {
      String? fileExt = Path.getFileExt(pickedFile);
      if (fileExt == null || fileExt.isEmpty) {
        switch (mediaType) {
          case MediaType.image:
            fileExt = 'jpeg';
            break;
          case MediaType.audio:
            fileExt = 'mp3';
            break;
          case MediaType.video:
            fileExt = 'mp4';
            break;
        }
      }
      String randomPath = await Path.getCacheFile("cache", fileExt: fileExt);
      returnFile = File(randomPath);
      if (!await returnFile.exists()) {
        returnFile.createSync(recursive: true);
      }
      returnFile = compressFile.copySync(randomPath);
    }
    logger.i('MediaPicker - pickSingle - return - path:${returnFile.path}');
    return returnFile;
  }

  static Future<File?> pickImageAndVideoBySystem({
    ImageSource source = ImageSource.gallery,
    int mediaType = MediaType.image,
    CropStyle? cropStyle,
    CropAspectRatio? cropRatio,
    int compressQuality = 100,
    String? returnPath,
    Duration? maxDuration,
  }) async {
    // permission
    Permission permission;
    if (source == ImageSource.camera) {
      permission = Permission.camera;
    } else if (source == ImageSource.gallery) {
      permission = Permission.mediaLibrary;
    } else {
      return null;
    }
    PermissionStatus permissionStatus = await permission.request();
    if (permissionStatus != PermissionStatus.granted) {
      return null;
    }

    // pick
    XFile? pickedResult;
    if (mediaType == MediaType.video) {
      pickedResult = await ImagePicker().pickVideo(source: source, maxDuration: maxDuration);
    } else {
      pickedResult = await ImagePicker().pickImage(source: source); // imageQuality: compressQuality  -> ios ino enable
    }
    if (pickedResult == null || pickedResult.path.isEmpty) {
      logger.w("MediaPicker - pickImageAndVideoBySystem - pickedResult = null"); // eg:/data/user/0/org.nkn.mobile.app.debug/cache/image_picker3336694179441112013.jpg
      return null;
    }
    File pickedFile = File(pickedResult.path);
    logger.i("MediaPicker - pickImageAndVideoBySystem - picked - path:${pickedFile.path}"); // eg:/data/user/0/org.nkn.mobile.app.debug/cache/image_picker3336694179441112013.jpg
    pickedFile.length().then((value) {
      logger.i('MediaPicker - pickImageAndVideoBySystem - picked - size:${formatFlowSize(value.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
    });

    // crop
    File? croppedFile = await _cropFile(pickedFile, mediaType, cropStyle, cropRatio);
    if (croppedFile == null) {
      logger.w('MediaPicker - pickImageAndVideoBySystem - croppedFile = null}');
      return null;
    }

    // compress
    File? compressFile = await _compressFile(croppedFile, mediaType, compressQuality);
    if (compressFile == null) {
      logger.w('MediaPicker - pickImageAndVideoBySystem - compress = null}');
      return null;
    }

    // return
    File returnFile;
    if (returnPath != null && returnPath.isNotEmpty) {
      returnFile = File(returnPath);
      if (!await returnFile.exists()) {
        returnFile.createSync(recursive: true);
      }
      returnFile = compressFile.copySync(returnPath);
    } else {
      String? fileExt = Path.getFileExt(pickedFile);
      if (fileExt == null || fileExt.isEmpty) {
        switch (mediaType) {
          case MediaType.image:
            fileExt = 'jpeg';
            break;
          case MediaType.audio:
            fileExt = 'mp3';
            break;
          case MediaType.video:
            fileExt = 'mp4';
            break;
        }
      }
      String randomPath = await Path.getCacheFile("cache", fileExt: fileExt);
      returnFile = File(randomPath);
      if (!await returnFile.exists()) {
        returnFile.createSync(recursive: true);
      }
      returnFile = compressFile.copySync(randomPath);
    }
    logger.i('MediaPicker - pickImageAndVideoBySystem - return - path:${returnFile.path}');
    return returnFile;
  }

  static Future<File?> _cropFile(File? original, int mediaType, CropStyle? cropStyle, CropAspectRatio? cropRatio) async {
    if (original == null) return null;
    bool isGif = (mime(original.path)?.indexOf('image/gif') ?? -1) >= 0;
    bool isImage = ((mime(original.path)?.indexOf('image') ?? -1) >= 0) || (mediaType == MediaType.image);
    if (cropStyle == null || isGif || !isImage) {
      return original;
    }
    // crop
    File? cropFile = await ImageCropper.cropImage(
      sourcePath: original.path,
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
    logger.i('MediaPicker - _cropImage - crop - path:${cropFile?.path}');
    cropFile?.length().then((value) {
      logger.i('MediaPicker - _compressFile - crop - size:${formatFlowSize(value.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
    });
    return cropFile;
  }

  static Future<File?> _compressFile(File? original, int mediaType, int compressQuality) async {
    if (original == null) return null;
    bool isGif = (mime(original.path)?.indexOf('image/gif') ?? -1) >= 0;
    bool isImage = ((mime(original.path)?.indexOf('image') ?? -1) >= 0) || (mediaType == MediaType.image);
    if (compressQuality >= 100 || isGif || !isImage) {
      return original;
    }
    // filePath
    String? fileExt = Path.getFileExt(original);
    if (fileExt == null || fileExt.isEmpty) {
      switch (mediaType) {
        case MediaType.image:
          fileExt = 'jpeg';
          break;
        case MediaType.audio:
          fileExt = 'mp3';
          break;
        case MediaType.video:
          fileExt = 'mp4';
          break;
      }
    }
    String compressPath = await Path.getCacheFile("cache", fileExt: fileExt);
    // format
    CompressFormat? format;
    if (compressPath.endsWith(".jpg") || compressPath.endsWith(".jpeg")) {
      format = CompressFormat.jpeg;
    } else if (compressPath.endsWith(".png")) {
      format = CompressFormat.png;
    } else if (compressPath.endsWith(".heic")) {
      format = CompressFormat.heic;
    } else if (compressPath.endsWith(".webp")) {
      format = CompressFormat.webp;
    }
    if (format == null) {
      return original;
    }
    // compress
    File? compressFile = await FlutterImageCompress.compressAndGetFile(
      original.path,
      compressPath,
      quality: compressQuality,
      autoCorrectionAngle: true,
      numberOfRetries: 3,
      format: format,
      // minWidth: 300,
      // minHeight: 300,
    );
    logger.i('MediaPicker - _compressFile - compress - format:$format - path:${compressFile?.path}');
    compressFile?.length().then((value) {
      logger.i('MediaPicker - _compressFile - compress - size:${formatFlowSize(value.toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
    });
    return compressFile;
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime_type/mime_type.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaType {
  static const int image = 0;
  static const int audio = 1;
  static const int video = 2;
}

class MediaPicker {
  static Future<File?> pick({
    ImageSource source = ImageSource.gallery,
    int mediaType = MediaType.image,
    CropStyle? cropStyle,
    CropAspectRatio? cropRatio,
    int compressQuality = 100,
    String? returnPath,
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
    PickedFile? pickedResult = await ImagePicker().getImage(source: source); // TODO:GG 估计得替换了
    if (pickedResult == null || pickedResult.path.isEmpty) {
      return null;
    }
    File pickedFile = File(pickedResult.path);
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
    bool isGif = (mime(pickedFile.path)?.indexOf('image/gif') ?? -1) >= 0;
    logger.i("MediaPicker - media_pick - picked - path:${pickedFile.path} - ext:$fileExt"); // eg:/data/user/0/org.nkn.mobile.app.debug/cache/image_picker3336694179441112013.jpg
    // logger.d('MediaPicker - media_pick - picked - size:${formatFlowSize(pickedFile.lengthSync().toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');

    // crop
    File? croppedFile;
    if (cropStyle == null || isGif) {
      croppedFile = pickedFile;
    } else {
      croppedFile = await ImageCropper.cropImage(
        sourcePath: pickedFile.path,
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
      logger.i('MediaPicker - media_pick - crop - path:${croppedFile?.path}');
      // logger.d('MediaPicker - media_pick - crop - size:${formatFlowSize(croppedFile?.lengthSync().toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
    }
    if (croppedFile == null) return null;

    // compress
    File? compressFile;
    if (compressQuality >= 100 || isGif) {
      compressFile = croppedFile;
    } else if (compressQuality < 100) {
      String compressPath = await Path.getCacheFile(null, fileExt: fileExt);
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
        compressFile = croppedFile;
      } else {
        if (mediaType == MediaType.image) {
          compressFile = await FlutterImageCompress.compressAndGetFile(
            croppedFile.path,
            compressPath,
            quality: compressQuality,
            autoCorrectionAngle: true,
            numberOfRetries: 3,
            format: format,
            // minWidth: 300,
            // minHeight: 300,
          );
        } else {
          compressFile = croppedFile;
        }
      }
      logger.i('MediaPicker - media_pick - compress - format:$format - path:${compressFile?.path}');
      // logger.d('MediaPicker - media_pick - compress - size:${formatFlowSize(compressFile?.lengthSync().toDouble(), unitArr: ['B', 'KB', 'MB', 'GB'])}');
    }
    if (compressFile == null) return null;

    // return
    File returnFile;
    if (returnPath != null && returnPath.isNotEmpty) {
      returnFile = File(returnPath);
      if (!await returnFile.exists()) {
        returnFile.createSync(recursive: true);
      }
      returnFile = compressFile.copySync(returnPath);
    } else {
      String randomPath = await Path.getCacheFile(null, fileExt: fileExt);
      returnFile = File(randomPath);
      if (!await returnFile.exists()) {
        returnFile.createSync(recursive: true);
      }
      returnFile = compressFile.copySync(randomPath);
    }
    logger.i('MediaPicker - media_pick - return - path:${returnFile.path}');
    return returnFile;
  }
}

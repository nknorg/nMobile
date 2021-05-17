import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaType {
  static const int image = 0;
  static const int audio = 1;
  static const int video = 2;
}

class MediaPicker {
  static Future<File> pick(
    String pubKey, {
    ImageSource source = ImageSource.gallery,
    int mediaType = MediaType.image,
    bool crop = false,
    int compressQuality = 100,
    String returnPath,
  }) async {
    // permission
    Permission permission;
    if (source == ImageSource.camera) {
      permission = Permission.camera;
    } else if (source == ImageSource.gallery) {
      permission = Permission.mediaLibrary;
    }
    PermissionStatus permissionStatus = await permission?.request();
    if (permissionStatus == null || permissionStatus != PermissionStatus.granted) {
      return null;
    }
    // pick
    PickedFile pickedResult = await ImagePicker().getImage(source: source);
    if (pickedResult == null || pickedResult.path == null || pickedResult.path.isEmpty) {
      return null;
    }
    File pickedFile = File(pickedResult.path);
    logger.d("pick - picked - path:${pickedFile?.path}"); // eg:/data/user/0/org.nkn.mobile.app.debug/cache/image_picker3336694179441112013.jpg
    if (pickedFile == null) {
      return null;
    }
    String fileExt = Path.getFileExt(pickedFile);
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
    // crop
    File croppedFile;
    if (!crop) {
      croppedFile = pickedFile;
    } else if (crop) {
      croppedFile = await ImageCropper.cropImage(
        sourcePath: pickedFile.path,
        // cropStyle: CropStyle.circle,
        maxWidth: 300,
        maxHeight: 300,
        compressQuality: 50,
        iosUiSettings: IOSUiSettings(
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
      logger.d('pick - crop - path:${croppedFile.path}');
    }
    // compress
    File compressFile;
    if (compressQuality >= 100) {
      compressFile = croppedFile;
    } else if (compressQuality < 100) {
      String compressPath = await Path.getRandomFilePath(pubKey, SubDirName.cache, ext: fileExt);
      if (mediaType == MediaType.image) {
        compressFile = await FlutterImageCompress.compressAndGetFile(
          pickedResult.path,
          compressPath,
          quality: compressQuality,
          autoCorrectionAngle: true,
          numberOfRetries: 3,
          format: CompressFormat.jpeg,
          minWidth: 300,
          minHeight: 300,
        );
      }
      logger.d('pick - compress - path:${compressFile.path}');
    }
    // return
    File returnFile;
    if (returnPath != null && returnPath.isNotEmpty) {
      returnFile = returnFile.copySync(returnPath);
    } else {
      String fileExt = Path.getFileExt(pickedFile);
      if (fileExt == null || fileExt.isEmpty) {
        String randomPath = await Path.getRandomFilePath(pubKey, SubDirName.cache, ext: fileExt);
        returnFile = compressFile.copySync(randomPath);
      } else {
        String cachePath = await Path.getFilePathByOriginal(pubKey, SubDirName.cache, compressFile);
        returnFile = compressFile.copySync(cachePath);
      }
    }
    logger.d('pick - return - path:${returnFile.path}');
    return returnFile;
  }
}

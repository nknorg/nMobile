import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime_type/mime_type.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/screens/chat/authentication_helper.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:permission_handler/permission_handler.dart';

Future<File> getCameraFile(String accountPubkey, {@required ImageSource source}) async {
  File image = await ImagePicker.pickImage(source: source);
  if (image != null) {
    File savedImg;
    if (mime(image.path).indexOf('image/gif') > -1) {
      var path = createFileCachePath(accountPubkey, image);
      savedImg = image.copySync(path);
    } else {
      savedImg = await compressAndGetFile(accountPubkey, image);
    }

    int fileLength = await savedImg.length();
    print('File Size is_____'+fileLength.toString());
    print('Image.path is___'+image.path);
    return savedImg;
  } else {
    return null;
  }
}

Future<File> getHeaderImage(String accountPubkey) async {
  File image;

  // Permission permission = Permission.camera;
  // var cameraStatus = await permission.request();
  // // Future camera
  // if (cameraStatus == PermissionStatus.granted){
  //   image = await ImagePicker.pickImage(source: ImageSource.camera);
  // }

  Permission mediaPermission = Permission.mediaLibrary;
  if (image == null){
    var mediaStatus = await mediaPermission.request();
    if (mediaStatus == PermissionStatus.granted){
      image = await ImagePicker.pickImage(source: ImageSource.gallery);
    }
  }

  if (image == null){
    return null;
  }

  File croppedFile = await ImageCropper.cropImage(
    sourcePath: image.path,
    cropStyle: CropStyle.circle,
    maxWidth: 300,
    maxHeight: 300,
    compressQuality: 50,
    iosUiSettings: IOSUiSettings(
      minimumAspectRatio: 1.0,
    ),
    androidUiSettings: AndroidUiSettings(toolbarTitle: 'Cropper', toolbarColor: Colors.deepOrange, toolbarWidgetColor: Colors.white, initAspectRatio: CropAspectRatioPreset.original, lockAspectRatio: false),
  );

  var path = createContactFilePath(accountPubkey, croppedFile);

  var savedImg = croppedFile.copySync(path);

  int length = await savedImg.length();
  NLog.w('savedImg length is_____'+length.toString());

  return savedImg;
}

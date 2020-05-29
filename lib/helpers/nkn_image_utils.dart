import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime_type/mime_type.dart';
import 'package:nmobile/helpers/utils.dart';

Future<File> getCameraFile({@required ImageSource source}) async {
  File image = await ImagePicker.pickImage(source: source);
  if (image != null) {
    File savedImg;
    if (mime(image.path).indexOf('image/gif') > -1) {
      var path = createFileCachePath(image);
      savedImg = image.copySync(path);
    } else {
      savedImg = await compressAndGetFile(image);
    }
    return savedImg;
  } else {
    return null;
  }
}

Future<File> getHeaderImage() async {
  File image = await ImagePicker.pickImage(source: ImageSource.gallery);
  File croppedFile = await ImageCropper.cropImage(
    sourcePath: image.path,
    cropStyle: CropStyle.circle,
    compressQuality: 0,
    iosUiSettings: IOSUiSettings(
      minimumAspectRatio: 1.0,
    ),
    androidUiSettings: AndroidUiSettings(toolbarTitle: 'Cropper', toolbarColor: Colors.deepOrange, toolbarWidgetColor: Colors.white, initAspectRatio: CropAspectRatioPreset.original, lockAspectRatio: false),
  );
  var path = createContactFilePath(croppedFile);
  var savedImg = croppedFile.copySync(path);
  return savedImg;
}

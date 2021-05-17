import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime_type/mime_type.dart';
import 'package:nmobile/common/global.dart';
import 'package:path/path.dart';

import '../utils/path.dart';

class Asset {
  static SvgPicture svg(
    String path, {
    double width,
    double height,
    Color color,
    BoxFit fit = BoxFit.contain,
    AlignmentGeometry align = Alignment.center,
    Clip clip = Clip.none,
  }) {
    return SvgPicture.asset(
      'assets/$path.svg',
      width: width,
      height: height,
      color: color,
      fit: fit,
      alignment: align,
      clipBehavior: clip,
    );
  }

  static SvgPicture iconSvg(
    String name, {
    double width,
    double height,
    Color color,
    BoxFit fit = BoxFit.contain,
    AlignmentGeometry align = Alignment.center,
    Clip clip = Clip.none,
  }) {
    return svg(
      'icons/$name',
      width: width,
      height: height,
      color: color,
      fit: fit,
      align: align,
      clip: clip,
    );
  }

  static Image image(
    String path, {
    double width,
    double height,
    Color color,
    double scale = 1,
    BoxFit fit = BoxFit.contain,
    AlignmentGeometry align = Alignment.center,
  }) {
    return Image.asset(
      'assets/$path',
      width: width,
      height: height,
      color: color,
      scale: scale,
      fit: fit,
      alignment: align,
    );
  }
}

// TODO:GG refactor

String createRandomWebPFile(String accountPubkey) {
  var value = new DateTime.now().millisecondsSinceEpoch.toString();
  Directory rootDir = Global.applicationRootDirectory;
  Directory dir = Directory(join(rootDir.path, accountPubkey));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  String path = join(rootDir.path, dir.path, value.toString() + '_temp.jpeg');
  return path;
}

Future<File> compressAndGetFile(String accountPubkey, File file) async {
  final dir = Global.applicationRootDirectory;

  final targetPath = createRandomWebPFile(accountPubkey);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  var result = await FlutterImageCompress.compressAndGetFile(file.absolute.path, targetPath, quality: 30, minWidth: 640, minHeight: 1024, format: CompressFormat.jpeg);
  return result;
}

Future<File> getCameraFile(String accountPubkey, {@required ImageSource source}) async {
  File image;
  final picker = ImagePicker();
  final pickedFile = await picker.getImage(source: source);

  if (pickedFile != null) {
    image = File(pickedFile.path);
  }

  if (image != null) {
    File savedImg;
    if (mime(image.path).indexOf('image/gif') > -1) {
      var path = createFileCachePath(accountPubkey, image);
      savedImg = image.copySync(path);
    } else {
      savedImg = await compressAndGetFile(accountPubkey, image);
    }

    return savedImg;
  } else {
    return null;
  }
}

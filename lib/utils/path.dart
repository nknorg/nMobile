import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/helpers/logger.dart';
import 'package:path/path.dart';

class SubDirName {
  static const String cache = "cache";
  static const String data = "data";
  static const String chat = "chat";
  static const String contact = "contact";
}

class Path {
  static String getFileName(String path) {
    return path?.split('/')?.last;
  }

  static Future<String> getFileMD5(File file) async {
    if (file == null) return null;
    Uint8List fileBytes = await file?.readAsBytes();
    return hexEncode(md5.convert(fileBytes).bytes);
  }

  static String getFileExt(File file) {
    String fullName = file?.path?.split('/')?.last;
    String fileExt;
    int index = fullName.lastIndexOf('.');
    if (index > -1) {
      fileExt = fullName?.split('.')?.last;
    }
    return fileExt;
  }

  static String joinFileExt(String fileName, String fileExt) {
    if (fileExt == null || fileExt.isEmpty) {
      return fileName;
    } else {
      return join(fileName + '.' + fileExt);
    }
  }

  /// eg:/{firstDir}/{secondDir}/{fileName}
  static String getLocalFilePath(String firstDirName, String secondDirName, String filePath) {
    return join(firstDirName, secondDirName, Path.getFileName(filePath));
  }

  /// eg:/data/user/0/org.nkn.mobile.app.debug/app_flutter/{firstDirName}/{secondDirName}/
  static Future<String> getDirPath(String firstDirName, String secondDirName) async {
    if (firstDirName == null || firstDirName.isEmpty || secondDirName == null || secondDirName.isEmpty) {
      logger.w('Wrong!!!!! getDirPath something is null');
      return null;
    }
    String dirPath = join(Global.applicationRootDirectory?.path, firstDirName, secondDirName);
    Directory dir = Directory(dirPath);
    if (!await dir.exists()) {
      dir = await dir.create(recursive: true);
    }
    logger.d("getDirPath - path:${dir?.path}");
    return dir?.path;
  }

  /// eg:/data/user/0/org.nkn.mobile.app.debug/app_flutter/{firstDirName}/{secondDirName}/{fileName}.{fileExt}
  static Future<String> getFilePath(String firstDirName, String secondDirName, String fileName, {String fileExt}) async {
    String dirPath = await getDirPath(firstDirName, secondDirName);
    if (dirPath == null || dirPath.isEmpty) {
      logger.w('Wrong!!!!! getFilePath dirPath is null');
      return null;
    }
    String path = join(dirPath, joinFileExt(fileName, fileExt));
    logger.d("getFilePath - path:$path");
    return path;
  }

  static Future<String> getFilePathByOriginal(String firstDirName, String secondDirName, File file) async {
    if (file == null) {
      logger.w('Wrong!!!!! getFilePathByOriginal file is null');
      return null;
    }
    String name = await getFileMD5(file);
    String fileExt = getFileExt(file);
    String path = await getFilePath(firstDirName, secondDirName, joinFileExt(name, fileExt));
    logger.d("getFilePathByOriginal - path:$path");
    return path;
  }

  static Future<String> getRandomFilePath(String firstDirName, String secondDirName, {String ext}) async {
    var timestamp = new DateTime.now().millisecondsSinceEpoch.toString();
    String fileName = join(timestamp, '_temp');
    if (ext != null && ext.isNotEmpty) {
      fileName += ".$ext";
    }
    String path = await getFilePath(firstDirName, secondDirName, fileName, fileExt: ext);
    logger.d("getRandomFilePath - path:$path");
    return path;
  }
}

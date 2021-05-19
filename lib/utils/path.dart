import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:path/path.dart';

class SubDirType {
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

  /// eg:/data/user/0/org.nkn.mobile.app/app_flutter/{mClientAddress}/{dirType}/
  static Future<String> getDir(String mClientAddress, String dirType) async {
    String dirPath = Global.applicationRootDirectory?.path;
    if (dirPath == null || dirPath.isEmpty) {
      return null;
    }
    if (mClientAddress != null && mClientAddress.isNotEmpty) {
      dirPath = join(dirPath, mClientAddress);
    }
    if (dirType != null && dirType.isNotEmpty) {
      dirPath = join(dirPath, dirType);
    }
    Directory dir = Directory(dirPath);
    if (!await dir.exists()) {
      dir = await dir.create(recursive: true);
    }
    logger.d("getDir - path:${dir?.path}");
    return dir?.path;
  }

  /// eg:/data/user/0/org.nkn.mobile.app/app_flutter/{mClientAddress}/{dirType}/{fileName}.{fileExt}
  static Future<String> getFile(String mClientAddress, String dirType, String fileName, {String fileExt}) async {
    String dirPath = await getDir(mClientAddress, dirType);
    if (dirPath == null || dirPath.isEmpty) {
      logger.w('getFile - dirPath == null');
      return null;
    }
    String path = join(dirPath, joinFileExt(fileName, fileExt));
    logger.d("getFile - path:$path");
    return path;
  }

  // static Future<String> getFilePathByOriginal(String firstDirName, String secondDirName, File file) async {
  //   if (file == null) {
  //     logger.w('Wrong!!!!! getFilePathByOriginal file is null');
  //     return null;
  //   }
  //   String name = await getFileMD5(file);
  //   String fileExt = getFileExt(file);
  //   String path = await getFilePath(firstDirName, secondDirName, joinFileExt(name, fileExt));
  //   logger.d("getFilePathByOriginal - path:$path");
  //   return path;
  // }

  /// eg:/data/user/0/org.nkn.mobile.app/app_flutter/{mClientAddress}/{dirType}/{fileName}.{fileExt}
  static Future<String> getCacheFile(String mClientAddress, {String ext}) async {
    String fileName = new DateTime.now().second.toString() + "_" + uuid.v4() + '_temp';
    if (ext != null && ext.isNotEmpty) {
      fileName += ".$ext";
    }
    String path = await getFile(mClientAddress, SubDirType.cache, fileName, fileExt: ext);
    logger.d("getCacheFile - path:$path");
    return path;
  }

  /// {mClientAddress}/{dirType}/{fileName}
  static String getLocalFile(String mClientAddress, String dirType, String filePath) {
    return join(mClientAddress, dirType, Path.getFileName(filePath));
  }

  /// {mClientAddress}/contact/{fileName}
  static String getLocalContactAvatar(String mClientAddress, String fileName) {
    return Path.getLocalFile(mClientAddress, SubDirType.contact, fileName);
  }
}

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/global.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

import 'logger.dart';

class SubDirType {
  static const String cache = "cache";
  static const String chat = "chat";
  static const String contact = "contact";
}

class Path {
  static String getFileName(String path) {
    return path.split('/').last;
  }

  static Future<String?> getFileMD5(File? file) async {
    if (file == null) return null;
    Uint8List fileBytes = await file.readAsBytes();
    return hexEncode(Uint8List.fromList(md5.convert(fileBytes).bytes));
  }

  static String? getFileExt(File? file) {
    String? fullName = file?.path.split('/').last;
    String? fileExt;
    int? index = fullName?.lastIndexOf('.');
    if (index != null && index > -1) {
      fileExt = fullName?.split('.').last;
    }
    return fileExt;
  }

  static String joinFileExt(String fileName, String? fileExt) {
    if (fileExt == null || fileExt.isEmpty) {
      return fileName;
    } else {
      return join(fileName + '.' + fileExt);
    }
  }

  /// eg:/data/user/0/org.nkn.mobile.app/app_flutter/{mPubKey}/{dirType}/
  static Future<String> getDir(String? mPubKey, String? dirType) async {
    String dirPath = Global.applicationRootDirectory.path;
    if (mPubKey != null && mPubKey.isNotEmpty) {
      dirPath = join(dirPath, mPubKey);
    }
    if (dirType != null && dirType.isNotEmpty) {
      dirPath = join(dirPath, dirType);
    }
    Directory dir = Directory(dirPath);
    if (!await dir.exists()) {
      dir = await dir.create(recursive: true);
    }
    // logger.d("Path - getDir - path:${dir.path}");
    return dir.path;
  }

  /// eg:/data/user/0/org.nkn.mobile.app/app_flutter/{mPubKey}/{dirType}/{fileName}.{fileExt}
  static Future<String> _getFile(String? mPubKey, String? dirType, String fileName, {String? fileExt}) async {
    String dirPath = await getDir(mPubKey, dirType);
    String path = join(dirPath, joinFileExt(fileName, fileExt));
    // logger.d("Path - getFile - path:$path");
    return path;
  }

  /// eg:/data/user/0/org.nkn.mobile.app/app_flutter/{mPubKey}/{dirType}/{fileName}.{fileExt}
  static Future<String> getCacheFile(String? mPubKey, {String? fileExt}) async {
    String fileName = new DateTime.now().second.toString() + "_" + Uuid().v4() + '_temp';
    if (fileExt != null && fileExt.isNotEmpty) {
      fileName += ".$fileExt";
    }
    String path = await _getFile(mPubKey, SubDirType.cache, fileName, fileExt: fileExt);
    logger.d("Path - getCacheFile - path:$path");
    return path;
  }

  /// eg:{rootPath}/{localPath}
  static String getCompleteFile(String? localPath) {
    return join(Global.applicationRootDirectory.path, localPath);
  }

  /// eg:{localPath}
  static String? getLocalFile(String? filePath) {
    if (filePath == null || filePath.isEmpty) return null;
    String rootDir = Global.applicationRootDirectory.path.endsWith("/") ? Global.applicationRootDirectory.path : (Global.applicationRootDirectory.path + "/");
    return filePath.split(rootDir).last;
  }

  /// eg:{mPubKey}/{dirType}/{fileName}
  static String createLocalFile(String? mPubKey, String? dirType, String filePath) {
    return join(mPubKey ?? "", dirType, Path.getFileName(filePath));
  }
}

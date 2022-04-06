import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/global.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class SubDirType {
  static const cache = "cache";
  static const download = "nkn";
  static const chat = "chat";
  static const contact = "contact";
  static const topic = "topic";
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

  // TODO:GG 修改所有的jpg
  // TODO:GG 所有文件的后缀，统一管理
  static String getFileExt(File? file, String defExt) {
    String? fullName = file?.path.split('/').last;
    String? fileExt;
    int? index = fullName?.lastIndexOf('.');
    if (index != null && index > -1) {
      fileExt = fullName?.split('.').last;
    }
    if (fileExt == null || fileExt.isEmpty) return defExt;
    return fileExt;
  }

  static String joinFileExt(String filePath, String? fileExt) {
    if (fileExt == null || fileExt.isEmpty) {
      return filePath;
    } else {
      List<String> party = filePath.split("/");
      int index = party[(party.length - 1) >= 0 ? party.length - 1 : 0].lastIndexOf(".");
      if (index < 0) {
        return join(filePath + '.' + fileExt);
      }
      index = filePath.lastIndexOf(".");
      filePath = filePath.substring(0, index);
      return join(filePath + '.' + fileExt);
    }
  }

  /**
   ******************************************************************************************************************************
   ******************************************************************************************************************************
   */

  /// eg:/data/user/0/org.nkn.mobile.app/app_flutter/{mPubKey}/{dirType}/
  static Future<String> getDir(String? mPubKey, String? dirType, {String? target}) async {
    String dirPath = Global.applicationRootDirectory.path;
    if (mPubKey != null && mPubKey.isNotEmpty) {
      dirPath = join(dirPath, mPubKey);
    }
    if (dirType != null && dirType.isNotEmpty) {
      dirPath = join(dirPath, dirType);
    }
    if (target != null && target.isNotEmpty) {
      dirPath = join(dirPath, target);
    }
    Directory dir = Directory(dirPath);
    if (!await dir.exists()) {
      dir = await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// eg:/data/user/0/org.nkn.mobile.app/app_flutter/{mPubKey}/{dirType}/{fileName}.{fileExt}
  static Future<String> _getFile(String? mPubKey, String? dirType, String fileName, {String? target, String? fileExt}) async {
    String dirPath = await getDir(mPubKey, dirType, target: target);
    String path = join(dirPath, joinFileExt(fileName, fileExt));
    return path;
  }

  /// eg:/data/user/0/org.nkn.mobile.app/app_flutter/{mPubKey}/{dirType}/{random}.{fileExt}
  static Future<String> getRandomFile(String? mPubKey, String dirType, {String? target, String? fileExt}) async {
    String fileName = new DateTime.now().second.toString() + "_" + Uuid().v4() + '_temp';
    if (fileExt != null && fileExt.isNotEmpty) {
      fileName += ".$fileExt";
    }
    String path = await _getFile(mPubKey, dirType, fileName, target: target, fileExt: fileExt);
    return path;
  }

  /**
   ******************************************************************************************************************************
   ******************************************************************************************************************************
   */

  /// eg:{rootPath}/{localPath}
  static String? getCompleteFile(String? localPath) {
    if (localPath == null || localPath.isEmpty) return null;
    return join(Global.applicationRootDirectory.path, localPath);
  }

  /// eg:{localPath}
  static String? getLocalFile(String? completePath) {
    if (completePath == null || completePath.isEmpty) return null;
    String rootDir = Global.applicationRootDirectory.path.endsWith("/") ? Global.applicationRootDirectory.path : (Global.applicationRootDirectory.path + "/");
    return completePath.split(rootDir).last;
  }
}

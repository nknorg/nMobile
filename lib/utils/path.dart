import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/global.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class DirType {
  static const cache = "cache";
  static const download = "nkn";
  static const profile = "profile";
  static const chat = "chat";
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
  static String getDir(String? uid, String? dirType, {String? subPath}) {
    String dirPath = Global.applicationRootDirectory.path;
    if (uid != null && uid.isNotEmpty) {
      dirPath = join(dirPath, uid);
    }
    if (dirType != null && dirType.isNotEmpty) {
      dirPath = join(dirPath, dirType);
    }
    if (subPath != null && subPath.isNotEmpty) {
      dirPath = join(dirPath, subPath);
    }
    return dirPath;
  }

  static Future<String> createDir(String? uid, String? dirType, {String? subPath}) async {
    String dirPath = getDir(uid, dirType, subPath: subPath);
    Directory dir = Directory(dirPath);
    if (!dir.existsSync()) dir = await dir.create(recursive: true);
    return dir.path;
  }

  /// eg:/data/user/0/org.nkn.mobile.app/app_flutter/{mPubKey}/{dirType}/{fileName}.{fileExt}
  static Future<String> getFile(String? uid, String? dirType, String fileName, {String? subPath, String? fileExt}) async {
    String dirPath = await createDir(uid, dirType, subPath: subPath);
    return join(dirPath, joinFileExt(fileName, fileExt));
  }

  static Future<String> createFile(String? uid, String? dirType, String fileName, {String? subPath, String? fileExt, bool reCreate = true}) async {
    String filePath = await getFile(uid, dirType, fileName, subPath: subPath, fileExt: fileExt);
    File file = File(filePath);
    if (file.existsSync()) {
      if (reCreate) {
        await file.delete();
        await file.create(recursive: true);
      }
    } else {
      await file.create(recursive: true);
    }
    return file.path;
  }

  /// eg:/data/user/0/org.nkn.mobile.app/app_flutter/{mPubKey}/{dirType}/{random}.{fileExt}
  static Future<String> getRandomFile(String? uid, String dirType, {String? subPath, String? fileExt}) async {
    String fileName = new DateTime.now().millisecondsSinceEpoch.toString() + '_temp_' + Uuid().v4();
    return await getFile(uid, dirType, fileName, subPath: subPath, fileExt: fileExt);
  }

  static Future<String> createRandomFile(String? uid, String dirType, {String? subPath, String? fileExt, bool reCreate = true}) async {
    String filePath = await getRandomFile(uid, dirType, subPath: subPath, fileExt: fileExt);
    File file = File(filePath);
    if (file.existsSync()) {
      if (reCreate) {
        await file.delete();
        await file.create(recursive: true);
      }
    } else {
      await file.create(recursive: true);
    }
    return file.path;
  }

  /**
   ******************************************************************************************************************************
   ******************************************************************************************************************************
   */

  /// eg:{rootPath}/{localPath}
  static String? convert2Complete(String? localPath) {
    if (localPath == null || localPath.isEmpty) return null;
    return join(Global.applicationRootDirectory.path, localPath);
  }

  /// eg:{localPath}
  static String? convert2Local(String? completePath) {
    if (completePath == null || completePath.isEmpty) return null;
    String rootDir = Global.applicationRootDirectory.path.endsWith("/") ? Global.applicationRootDirectory.path : (Global.applicationRootDirectory.path + "/");
    return completePath.split(rootDir).last;
  }
}

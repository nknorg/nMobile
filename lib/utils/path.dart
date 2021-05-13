import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/global.dart';
import 'package:path/path.dart';

String getFileName(String path) {
  return path?.split('/')?.last;
}

String getLocalPath(String pubkey, String path) {
  return join(pubkey, 'data', getFileName(path));
}

String getLocalContactPath(String accountPubkey, String path) {
  Directory rootDir = Global.applicationRootDirectory;
  Directory dir = Directory(join(rootDir.path, accountPubkey, 'contact'));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  return join(accountPubkey, 'contact', getFileName(path));
}

String createFileCachePath(String accountPubkey, File file) {
  String name = hexEncode(md5.convert(file.readAsBytesSync()).bytes);
  Directory rootDir = Global.applicationRootDirectory;
  Directory dir = Directory(join(rootDir.path, accountPubkey));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  String fullName = file?.path?.split('/')?.last;
  String fileExt;
  int index = fullName.lastIndexOf('.');
  if (index > -1) {
    fileExt = fullName?.split('.')?.last;
  }
  String path = join(rootDir.path, dir.path, name + '.' + fileExt);
  return path;
}
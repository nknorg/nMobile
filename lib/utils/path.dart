import 'dart:io';

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
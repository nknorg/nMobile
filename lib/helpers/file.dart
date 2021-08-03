import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';

class FileHelper {
  static Future<File?> convertBase64toFile(String? base64Data, String dirType, {String? extension, String? chatTarget}) async {
    if (base64Data == null || base64Data.isEmpty || clientCommon.publicKey == null) return null;
    if (extension == null || extension.isEmpty) {
      var match = RegExp(r'\(data:(.*);base64,(.*)\)').firstMatch(base64Data);
      var mimeType = match?.group(1) ?? "";
      var fileBase64 = match?.group(2);
      if (fileBase64 == null || fileBase64.isEmpty) return null;

      if (mimeType.indexOf('image/jpg') > -1 || mimeType.indexOf('image/jpeg') > -1) {
        extension = 'jpg';
      } else if (mimeType.indexOf('image/png') > -1) {
        extension = 'png';
      } else if (mimeType.indexOf('image/gif') > -1) {
        extension = 'gif';
      } else if (mimeType.indexOf('image/webp') > -1) {
        extension = 'webp';
      } else if (mimeType.indexOf('image/') > -1) {
        extension = mimeType.split('/').last;
      } else if (mimeType.indexOf('aac') > -1) {
        extension = 'aac';
      } else {
        logger.w('FileHelper - convertBase64toFile - no_extension');
      }
      base64Data = fileBase64;
    }

    Uint8List? bytes;
    try {
      bytes = base64Decode(base64Data);
    } catch (e) {
      handleError(e);
      return null;
    }
    String name = hexEncode(Uint8List.fromList(md5.convert(bytes).bytes));
    String localPath = Path.createLocalFile(hexEncode(clientCommon.publicKey!), dirType, '$name.$extension', chatTarget: chatTarget);
    File? file = Path.getCompleteFile(localPath) != null ? File(Path.getCompleteFile(localPath)!) : null;
    logger.d('MessageSchema - loadMediaFile - path:${file?.absolute}');
    if (file == null) return null;

    if (!await file.exists()) {
      file.createSync(recursive: true);
      logger.d('MessageSchema - loadMediaFile - write:${file.absolute}');
      await file.writeAsBytes(bytes, flush: true);
    }
    return file;
  }

  static String? getExtensionByBase64(String? base64Data) {
    if (base64Data == null || base64Data.isEmpty) return null;
    var match = RegExp(r'\(data:(.*);base64,(.*)\)').firstMatch(base64Data);
    var mimeType = match?.group(1) ?? "";
    var fileBase64 = match?.group(2);
    if (fileBase64 == null || fileBase64.isEmpty) return null;
    return getExtension(mimeType);
  }

  static String? getExtension(String? mimeType) {
    if (mimeType == null || mimeType.isEmpty) return null;
    var extension;
    if (mimeType.indexOf('image/jpg') > -1 || mimeType.indexOf('image/jpeg') > -1) {
      extension = 'jpg';
    } else if (mimeType.indexOf('image/png') > -1) {
      extension = 'png';
    } else if (mimeType.indexOf('image/gif') > -1) {
      extension = 'gif';
    } else if (mimeType.indexOf('image/webp') > -1) {
      extension = 'webp';
    } else if (mimeType.indexOf('image/') > -1) {
      extension = mimeType.split('/').last;
    } else if (mimeType.indexOf('aac') > -1) {
      extension = 'aac';
    }
    return extension;
  }
}

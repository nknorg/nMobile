import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mime_type/mime_type.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/utils/logger.dart';

class FileHelper {
  static Future<String?> convertFileToBase64(File? file, {String? type}) async {
    if (file == null) return null;
    if (!file.existsSync()) return null;
    String base64Data = base64Encode(file.readAsBytesSync());
    if (type?.isNotEmpty == true) {
      return '![$type](data:${mime(file.path)};base64,$base64Data)';
    } else {
      return base64Data;
    }
  }

  static Future<File?> convertBase64toFile(String? base64Data, Function(String?) getSavePath) async {
    if (base64Data == null || base64Data.isEmpty) return null;

    String? extension;
    RegExpMatch? match = RegExp(r'\(data:(.*);base64,(.*)\)').firstMatch(base64Data);
    String? mimeType = match?.group(1) ?? "";
    String? base64Real = match?.group(2);
    if (base64Real != null && base64Real.isNotEmpty) {
      base64Data = base64Real;
      String? ext = getExtension(mimeType);
      if (ext != null && ext.isNotEmpty) {
        extension = ext;
      }
      if (extension == null || extension.isEmpty) {
        logger.w('FileHelper - convertBase64toFile - no_extension');
      }
    }

    Uint8List? bytes;
    try {
      bytes = base64Decode(base64Data);
    } catch (e) {
      handleError(e);
      return null;
    }

    String filePath = await getSavePath(extension);
    File file = File(filePath);
    if (!await file.exists()) {
      await file.create(recursive: true);
      logger.d('MessageSchema - loadMediaFile - success - path:${file.absolute}');
      await file.writeAsBytes(bytes, flush: true);
    } else {
      logger.w('MessageSchema - loadMediaFile - exists - path:$filePath');
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

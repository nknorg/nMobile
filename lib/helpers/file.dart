import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mime_type/mime_type.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/utils/logger.dart';

class FileHelper {
  static const String DEFAULT_IMAGE_EXT = "jpeg";
  static const String DEFAULT_AUDIO_EXT = "aac";
  static const String DEFAULT_VIDEO_EXT = "mp4";

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
      String? ext = getExtensionByMimeType(mimeType);
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
    } catch (e, st) {
      handleError(e, st);
      return null;
    }

    String filePath = await getSavePath(extension);
    File file = File(filePath);
    if (!await file.exists()) {
      await file.create(recursive: true);
      logger.d('FileHelper - convertBase64toFile - success - path:${file.absolute}');
      await file.writeAsBytes(bytes, flush: true);
    } else {
      logger.w('FileHelper - convertBase64toFile - exists - path:$filePath');
    }
    return file;
  }

  static String? getExtensionByBase64(String? base64Data) {
    if (base64Data == null || base64Data.isEmpty) return null;
    var match = RegExp(r'\(data:(.*);base64,(.*)\)').firstMatch(base64Data);
    var mimeType = match?.group(1) ?? "";
    var fileBase64 = match?.group(2);
    if (fileBase64 == null || fileBase64.isEmpty) return null;
    return getExtensionByMimeType(mimeType);
  }

  static String? getExtensionByMimeType(String? mimeType) {
    if (mimeType == null || mimeType.isEmpty) return null;
    var extension;
    if (mimeType.indexOf('image/jpg') > -1 || mimeType.indexOf('image/jpeg') > -1) {
      extension = 'jpeg';
    } else if (mimeType.indexOf('image/png') > -1) {
      extension = 'png';
    } else if (mimeType.indexOf('image/gif') > -1) {
      extension = 'gif';
    } else if (mimeType.indexOf('image/webp') > -1) {
      extension = 'webp';
    } else if (mimeType.indexOf('aac') > -1) {
      extension = 'aac';
    } else {
      extension = mimeType.split('/').last;
    }
    return extension;
  }

  static bool isVideoByExt(String? fileExt) {
    if (fileExt == null || fileExt.isEmpty) return false;
    List<String> videos = ["mp4", "m4v", "avi", "av", "dat", "mkv", "flv", "vob", "mov", "3gp", "mpg", "mpeg", "mpe", "rm", "rmvb", "wmv", "asf", "asx"];
    bool isVideo = false;
    videos.forEach((element) {
      if (!isVideo) isVideo = fileExt.toLowerCase().contains(element.toLowerCase());
    });
    return isVideo;
  }

  static bool isAudioByExt(String? fileExt) {
    if (fileExt == null || fileExt.isEmpty) return false;
    List<String> audios = ["mp3", "wma", "aac", "wav", "mp2", "flac", "midi", "ra", "ape", "cda"];
    bool isAudio = false;
    audios.forEach((element) {
      if (!isAudio) isAudio = fileExt.toLowerCase().contains(element.toLowerCase());
    });
    return isAudio;
  }

  static bool isImageByExt(String? fileExt) {
    if (fileExt == null || fileExt.isEmpty) return false;
    List<String> images = ["bmp", "jpg", "jpeg", "png", "tif", "gif", "pcx", "tga", "exif", "fpx", "svg", "psd", "cdr", "pcd", "dxf", "ufo", "eps", "ai", "raw", "wmf", "webp", "avif", "apng"];
    bool isImage = false;
    images.forEach((element) {
      if (!isImage) isImage = fileExt.toLowerCase().contains(element.toLowerCase());
    });
    return isImage;
  }
}

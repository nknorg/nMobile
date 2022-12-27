import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/contact/home.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class ShareHelper {
  static Future showWithTexts(BuildContext? context, List<String> shareTexts) async {
    if (shareTexts.isEmpty) return;
    var target = await ContactHomeScreen.go(context, title: Global.locale((s) => s.share, ctx: context), selectContact: true, selectGroup: true);
    if (target == null) return;
    await _sendShareTexts(shareTexts, target);
  }

  static Future _sendShareTexts(List<String> shareTexts, dynamic target) async {
    if (target == null) return;
    // messages
    for (var i = 0; i < shareTexts.length; i++) {
      String result = shareTexts[i];
      if (result.isEmpty) continue;
      chatOutCommon.sendText(target, result); // await
    }
  }

  static Future showWithFiles(BuildContext? context, List<SharedMediaFile> shareMedias) async {
    if (shareMedias.isEmpty) return;
    var target = await ContactHomeScreen.go(context, title: Global.locale((s) => s.share, ctx: context), selectContact: true, selectGroup: true);
    if (target == null) return;
    // subPath
    String? subPath;
    if (target is ContactSchema) {
      List<String> splits = target.clientAddress.split(".");
      if (splits.length > 0) subPath = splits[0];
    } else if (target is TopicSchema) {
      subPath = Uri.encodeComponent(target.topic);
      if (subPath != target.topic) subPath = "common"; // FUTURE:GG encode
    } else if (target is PrivateGroupSchema) {
      subPath = Uri.encodeComponent(target.groupId);
      if (subPath != target.groupId) subPath = "common"; // FUTURE:GG encode
    } else {
      return;
    }
    await _sendShareMedias(shareMedias, target, subPath);
  }

  static Future _sendShareMedias(List<SharedMediaFile> shareMedias, dynamic target, String? subPath) async {
    if (target == null) return;
    // medias
    List<Map<String, dynamic>> results = [];
    for (var i = 0; i < shareMedias.length; i++) {
      SharedMediaFile result = shareMedias[i];
      Map<String, dynamic>? params = await _getParamsFromShareMedia(result, subPath, MessageSchema.ipfsMaxSize);
      if (params == null || params.isEmpty) continue;
      results.add(params);
    }
    if (results.isEmpty) return;
    // messages
    for (var i = 0; i < results.length; i++) {
      Map<String, dynamic> result = results[i];
      String path = result["path"] ?? "";
      int size = int.tryParse(result["size"]?.toString() ?? "") ?? File(path).lengthSync();
      String? mimeType = result["mimeType"];
      double durationS = double.tryParse(result["duration"]?.toString() ?? "") ?? 0;
      if (path.isEmpty) continue;
      // no message_type(video/file), and result no mime_type from file_picker
      // so big_file and video+file go with type_ipfs
      if ((mimeType?.contains("image") == true) && (size <= MessageSchema.piecesMaxSize)) {
        chatOutCommon.sendImage(target, File(path)); // await
      } else if ((mimeType?.contains("audio") == true) && (size <= MessageSchema.piecesMaxSize)) {
        chatOutCommon.sendAudio(target, File(path), durationS); // await
      } else {
        chatOutCommon.saveIpfs(target, result); // await
      }
    }
  }

  static Future<Map<String, dynamic>?> _getParamsFromShareMedia(SharedMediaFile shareMedia, String? subPath, int? maxSize) async {
    logger.i("ShareHelper - _getParamsFromShareMedia - SharedMediaFile:$shareMedia");
    // path
    if (shareMedia.path.isEmpty) {
      logger.e("ShareHelper - _getParamsFromShareMedia - path is empty");
      return null;
    }
    File file = File(shareMedia.path);
    if (!file.existsSync()) {
      logger.e("ShareHelper - _getParamsFromShareMedia - file is empty");
      return null;
    }
    // type
    String mimetype = "";
    if (shareMedia.type == SharedMediaType.IMAGE) {
      mimetype = "image";
    } else if (shareMedia.type == SharedMediaType.VIDEO) {
      mimetype = "video";
    } else if (shareMedia.type == SharedMediaType.FILE) {
      mimetype = "file";
    }
    // ext
    String ext = Path.getFileExt(file, "");
    if (ext.isEmpty) {
      if (shareMedia.type == SharedMediaType.IMAGE) {
        ext = FileHelper.DEFAULT_IMAGE_EXT;
      } else if (shareMedia.type == SharedMediaType.VIDEO) {
        ext = FileHelper.DEFAULT_VIDEO_EXT;
      }
    }
    // size
    int size = file.lengthSync();
    if (maxSize != null && maxSize > 0) {
      if (size >= maxSize) {
        Toast.show(Global.locale((s) => s.file_too_big));
        return null;
      }
    }
    // thumbnail
    String? thumbnailPath;
    int? thumbnailSize;
    if ((shareMedia.thumbnail != null) && (shareMedia.thumbnail?.isNotEmpty == true)) {
      File thumbnail = File(shareMedia.thumbnail ?? "");
      if (thumbnail.existsSync()) {
        thumbnailPath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: subPath, fileExt: FileHelper.DEFAULT_IMAGE_EXT);
        File saveThumbnail = File(thumbnailPath);
        if (!await saveThumbnail.exists()) {
          await saveThumbnail.create(recursive: true);
        } else {
          await saveThumbnail.delete();
          await saveThumbnail.create(recursive: true);
        }
        saveThumbnail = await thumbnail.copy(thumbnailPath);
        thumbnailSize = saveThumbnail.lengthSync();
      }
    }
    // media
    String filePath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: subPath, fileExt: ext);
    File saveFile = File(filePath);
    if (!await saveFile.exists()) {
      await saveFile.create(recursive: true);
    } else {
      await saveFile.delete();
      await saveFile.create(recursive: true);
    }
    saveFile = await file.copy(filePath);
    // map
    if (filePath.isNotEmpty) {
      int? duration = shareMedia.duration;
      Map<String, dynamic> params = {
        "path": filePath,
        "size": size,
        "name": null,
        "fileExt": ext.isEmpty ? null : ext,
        "mimeType": mimetype,
        "width": null,
        "height": null,
        "duration": (duration != null) ? (duration / 1000) : null,
        "thumbnailPath": thumbnailPath,
        "thumbnailSize": thumbnailSize,
      };
      return params;
    }
    return null;
  }
}

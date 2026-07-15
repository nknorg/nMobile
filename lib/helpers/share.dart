import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/helpers/media_picker.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/contact/home.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:share_handler/share_handler.dart';
import 'package:video_player/video_player.dart';

class ShareHelper {
  static Future showWithTexts(BuildContext? context, List<String> shareTexts) async {
    if (shareTexts.isEmpty) return;
    var target = await ContactHomeScreen.go(context, title: Settings.locale((s) => s.share, ctx: context), selectContact: true, selectGroup: true);
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

  static Future showWithFiles(BuildContext? context, SharedMedia shareMedia) async {
    // pick target first
    var target = await ContactHomeScreen.go(context, title: Settings.locale((s) => s.share, ctx: context), selectContact: true, selectGroup: true);
    if (target == null) return;
    // subPath
    String? subPath;
    if (target is ContactSchema) {
      List<String> splits = target.address.split(".");
      if (splits.length > 0) subPath = splits[0];
    } else if (target is TopicSchema) {
      subPath = Uri.encodeComponent(target.topicId);
      if (subPath != target.topicId) subPath = "common"; // FUTURE:GG encode
    } else if (target is PrivateGroupSchema) {
      subPath = Uri.encodeComponent(target.groupId);
      if (subPath != target.groupId) subPath = "common"; // FUTURE:GG encode
    } else {
      return;
    }
    // attachments from share_handler (filter out nulls)
    final List<SharedAttachment> attachments =
        (shareMedia.attachments ?? const <SharedAttachment?>[]).whereType<SharedAttachment>().toList();
    if (attachments.isEmpty) {
      // fallback to text if present
      final content = shareMedia.content?.trim();
      if (content != null && content.isNotEmpty) {
        await showWithTexts(context, [content]);
      }
      return;
    }
    await _sendShareAttachments(attachments, target, subPath);
  }

  static Future _sendShareAttachments(List<SharedAttachment> attachments, dynamic target, String? subPath) async {
    if (target == null) return;
    // medias
    List<Map<String, dynamic>> results = [];
    for (var i = 0; i < attachments.length; i++) {
      SharedAttachment attachment = attachments[i];
      Map<String, dynamic>? params = await _getParamsFromAttachment(attachment, subPath, Settings.sizeIpfsMax);
      if (params == null || params.isEmpty) continue;
      results.add(params);
    }
    if (results.isEmpty) return;
    String text = "";
    // messages
    for (var i = 0; i < results.length; i++) {
      Map<String, dynamic> result = results[i];
      String path = result["path"] ?? "";
      int size = int.tryParse(result["size"]?.toString() ?? "") ?? File(path).lengthSync();
      String? mimeType = result["mimeType"];
      double durationS = double.tryParse(result["duration"]?.toString() ?? "") ?? 0;
      String message = result["message"] ?? "";
      if (path.isEmpty) continue;
      // no message_type(video/file), and result no mime_type from file_picker
      // so big_file and video+file go with type_ipfs
      if ((mimeType?.contains("image") == true) && (size <= Settings.piecesMaxSize)) {
        chatOutCommon.sendImage(target, File(path)); // await
      } else if ((mimeType?.contains("audio") == true) && (size <= Settings.piecesMaxSize)) {
        chatOutCommon.sendAudio(target, File(path), durationS); // await
      } else {
        chatOutCommon.saveIpfs(target, result); // await
      }
      if (text.isEmpty && message.isNotEmpty) text = message;
    }
    if (text.isNotEmpty) {
      chatOutCommon.sendText(target, text); // await
    }
  }

  static Future<Map<String, dynamic>?> _getParamsFromAttachment(SharedAttachment attachment, String? subPath, int? maxSize) async {
    logger.i("ShareHelper - _getParamsFromAttachment - SharedAttachment:$attachment");
    // path from share_handler may be file:// URL
    String rawPath = attachment.path;
    if (rawPath.isEmpty) {
      logger.e("ShareHelper - _getParamsFromAttachment - path is empty");
      return null;
    }
    final String resolvedPath = rawPath.startsWith('file://') ? Uri.parse(rawPath).path : rawPath;
    File file = File(resolvedPath);
    if (!file.existsSync()) {
      logger.e("ShareHelper - _getParamsFromAttachment - file not exists: $resolvedPath");
      return null;
    }
    // type -> mime bucket
    String mimeType = "file";
    if (attachment.type == SharedAttachmentType.image) {
      mimeType = "image";
    } else if (attachment.type == SharedAttachmentType.video) {
      mimeType = "video";
    } else if (attachment.type == SharedAttachmentType.audio) {
      mimeType = "audio";
    }
    // ext
    String ext = Path.getFileExt(file, "");
    if (ext.isEmpty) {
      if (attachment.type == SharedAttachmentType.image) {
        ext = FileHelper.DEFAULT_IMAGE_EXT;
      } else if (attachment.type == SharedAttachmentType.video) {
        ext = FileHelper.DEFAULT_VIDEO_EXT;
      }
    }
    // size
    int size = file.lengthSync();
    if (maxSize != null && maxSize > 0) {
      if (size >= maxSize) {
        Toast.show(Settings.locale((s) => s.file_too_big));
        return null;
      }
    }
    // save
    String filePath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: subPath, fileExt: ext);
    File saveFile = File(filePath);
    if (!await saveFile.exists()) {
      await saveFile.create(recursive: true);
    } else {
      await saveFile.delete();
      await saveFile.create(recursive: true);
    }
    saveFile = await file.copy(filePath);
    // thumbnail
    String? thumbnailPath;
    int? thumbnailSize;
    double? durationSeconds;
    if (mimeType.contains("video") == true) {
      thumbnailPath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: subPath, fileExt: FileHelper.DEFAULT_IMAGE_EXT);
      Map<String, dynamic>? res = await MediaPicker.getVideoThumbnail(filePath, thumbnailPath);
      if (res != null && res.isNotEmpty) {
        thumbnailPath = res["path"];
        thumbnailSize = res["size"];
      }
      // duration
      try {
        var controller = VideoPlayerController.file(File(filePath));
        await controller.initialize();
        durationSeconds = controller.value.duration.inMilliseconds / 1000.0;
        await controller.dispose();
      } catch (_) {}
    } else if ((mimeType.contains("image") == true) && (size > Settings.piecesMaxSize)) {
      thumbnailPath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: subPath, fileExt: FileHelper.DEFAULT_IMAGE_EXT);
      File? thumbnail = await MediaPicker.compressImageBySize(File(filePath), savePath: thumbnailPath, maxSize: Settings.sizeThumbnailMax, bestSize: Settings.sizeThumbnailBest, force: true);
      if (thumbnail != null) {
        thumbnailPath = thumbnail.absolute.path;
        thumbnailSize = thumbnail.lengthSync();
      }
    }
    // map
    if (filePath.isNotEmpty) {
      Map<String, dynamic> params = {
        "path": filePath,
        "size": size,
        "name": null,
        "fileExt": ext.isEmpty ? null : ext,
        "mimeType": mimeType,
        "width": null,
        "height": null,
        "duration": durationSeconds,
        "thumbnailPath": thumbnailPath,
        "thumbnailSize": thumbnailSize,
        "message": null,
      };
      return params;
    }
    return null;
  }
}

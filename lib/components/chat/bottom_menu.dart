import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/file.dart';
import 'package:nmobile/helpers/media_picker.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';

class ChatBottomMenu extends StatelessWidget {
  final String? target;
  final bool show;
  final Function(List<Map<String, dynamic>> result)? onPicked;

  ChatBottomMenu({
    this.target,
    this.show = false,
    this.onPicked,
  });

  _pickImages({required ImageSource source}) async {
    if (!clientCommon.isClientCreated) return;
    List<Map<String, dynamic>> results;
    if (source == ImageSource.camera) {
      String savePath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: target, fileExt: FileHelper.DEFAULT_IMAGE_EXT);
      Map<String, dynamic>? result = await MediaPicker.takeCommon(
        savePath,
        maxDuration: Duration(seconds: 10),
      );
      if (result == null || result.isEmpty) return;
      results = []..add(result);
    } else {
      int maxNum = 9;
      List<String> savePaths = [];
      for (var i = 0; i < maxNum; i++) {
        String savePath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: target, fileExt: FileHelper.DEFAULT_IMAGE_EXT);
        savePaths.add(savePath);
      }
      results = await MediaPicker.pickCommons(
        savePaths,
        maxSize: MessageSchema.ipfsMaxSize,
      );
    }
    if (results.isEmpty) return;
    for (var i = 0; i < results.length; i++) {
      Map<String, dynamic> map = results[i];
      String? original = map["path"]?.toString();
      int? size = int.tryParse(map["size"]?.toString() ?? "");
      String? mimeType = map["mimeType"]?.toString();
      if ((original != null) && original.isNotEmpty && (mimeType != null) && mimeType.isNotEmpty) {
        if (mimeType.contains("video") == true) {
          String savePath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: target, fileExt: FileHelper.DEFAULT_IMAGE_EXT);
          Map<String, dynamic>? res = await MediaPicker.getVideoThumbnail(original, savePath);
          if (res != null && res.isNotEmpty) {
            results[i]["thumbnailPath"] = res["path"];
            results[i]["thumbnailSize"] = res["size"];
          }
        } else if (mimeType.contains("image") == true && ((size ?? 0) > MessageSchema.piecesMaxSize)) {
          String savePath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: target, fileExt: FileHelper.DEFAULT_IMAGE_EXT);
          File? thumbnail = await MediaPicker.compressImageBySize(File(original), savePath: savePath, maxSize: 200 * 1000, bestSize: 50 * 1000, force: true);
          if (thumbnail != null) {
            results[i]["thumbnailPath"] = thumbnail.absolute.path;
            results[i]["thumbnailSize"] = thumbnail.lengthSync();
          }
        }
      }
    }
    if (results.isEmpty) return;
    onPicked?.call(results);
  }

  _pickFiles({int? maxSize}) async {
    if (!clientCommon.isClientCreated) return;
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        allowCompression: true,
      );
    } catch (e) {
      handleError(e);
    }
    if (result == null || result.files.isEmpty) return;
    List<Map<String, dynamic>> results = [];
    for (var i = 0; i < result.files.length; i++) {
      PlatformFile picked = result.files[i];
      String? path = picked.path;
      String name = picked.name;
      if (path == null || path.isEmpty) continue;
      // copy
      String savePath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: target, fileExt: picked.extension);
      File file = File(path);
      int size = file.lengthSync();
      if (maxSize != null && maxSize > 0) {
        if (size >= maxSize) {
          Toast.show(Global.locale((s) => s.file_too_big));
          continue;
        }
      }
      await file.copy(savePath);
      // info
      String? fileExt = (picked.extension?.isNotEmpty == true) ? picked.extension : Path.getFileExt(file, "");
      String? mimeType;
      if (fileExt != null && fileExt.isNotEmpty) {
        if (FileHelper.isVideoByExt(fileExt)) {
          mimeType = "video";
        } else if (FileHelper.isAudioByExt(fileExt)) {
          mimeType = "audio";
        } else if (FileHelper.isImageByExt(fileExt)) {
          mimeType = "image";
        }
      }
      Map<String, dynamic> map = {
        "path": savePath,
        "size": size,
        "name": name,
        "fileExt": fileExt,
        "mimeType": mimeType,
        // "width": width,
        // "height": width,
        // "duration": duration,
      };
      // thumbnail
      if ((mimeType != null) && mimeType.isNotEmpty) {
        if (mimeType.contains("video") == true) {
          String thumbnailPath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: target, fileExt: FileHelper.DEFAULT_IMAGE_EXT);
          Map<String, dynamic>? res = await MediaPicker.getVideoThumbnail(savePath, thumbnailPath);
          if (res != null && res.isNotEmpty) {
            map["thumbnailPath"] = res["path"];
            map["thumbnailSize"] = res["size"];
          }
        } else if (mimeType.contains("image") == true) {
          String thumbnailPath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: target, fileExt: FileHelper.DEFAULT_IMAGE_EXT);
          File? thumbnail = await MediaPicker.compressImageBySize(File(savePath), savePath: thumbnailPath, maxSize: 200 * 1000, bestSize: 50 * 1000, force: true);
          if (thumbnail != null) {
            map["thumbnailPath"] = thumbnail.absolute.path;
            map["thumbnailSize"] = thumbnail.lengthSync();
          }
        }
      }
      results.add(map);
    }
    logger.i("BottomMenu - _pickFiles - results:$results");
    if (results.isEmpty) return;
    onPicked?.call(results);
  }

  @override
  Widget build(BuildContext context) {
    double btnSize = Global.screenWidth() / 6;
    double iconSize = btnSize / 2;

    return ExpansionLayout(
      isExpanded: show,
      child: Container(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: application.theme.backgroundColor2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: btnSize,
                  height: btnSize,
                  child: TextButton(
                    style: ButtonStyle(
                      shape: MaterialStateProperty.resolveWith((states) => RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)))),
                      backgroundColor: MaterialStateProperty.resolveWith((states) => application.theme.backgroundColor2),
                    ),
                    child: Icon(
                      CupertinoIcons.folder,
                      size: iconSize,
                      color: application.theme.fontColor2,
                    ),
                    onPressed: () {
                      _pickFiles(maxSize: MessageSchema.ipfsMaxSize);
                    },
                  ),
                ),
                SizedBox(height: 8),
                Label(
                  Global.locale((s) => s.files, ctx: context),
                  type: LabelType.bodySmall,
                  fontWeight: FontWeight.w600,
                  color: application.theme.fontColor4,
                ),
                SizedBox(height: 8),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: btnSize,
                  height: btnSize,
                  child: TextButton(
                    style: ButtonStyle(
                      shape: MaterialStateProperty.resolveWith((states) => RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)))),
                      backgroundColor: MaterialStateProperty.resolveWith((states) => application.theme.backgroundColor2),
                    ),
                    child: Asset.iconSvg(
                      'image',
                      width: iconSize,
                      color: application.theme.fontColor2,
                    ),
                    onPressed: () {
                      _pickImages(source: ImageSource.gallery);
                    },
                  ),
                ),
                SizedBox(height: 8),
                Label(
                  Global.locale((s) => s.album, ctx: context),
                  type: LabelType.bodySmall,
                  fontWeight: FontWeight.w600,
                  color: application.theme.fontColor4,
                ),
                SizedBox(height: 8),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: btnSize,
                  height: btnSize,
                  child: TextButton(
                    style: ButtonStyle(
                      shape: MaterialStateProperty.resolveWith((states) => RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)))),
                      backgroundColor: MaterialStateProperty.resolveWith((states) => application.theme.backgroundColor2),
                    ),
                    child: Asset.iconSvg(
                      'camera',
                      width: iconSize,
                      color: application.theme.fontColor2,
                    ),
                    onPressed: () {
                      _pickImages(source: ImageSource.camera);
                    },
                  ),
                ),
                SizedBox(height: 8),
                Label(
                  Global.locale((s) => s.camera, ctx: context),
                  type: LabelType.bodySmall,
                  fontWeight: FontWeight.w600,
                  color: application.theme.fontColor4,
                ),
                SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

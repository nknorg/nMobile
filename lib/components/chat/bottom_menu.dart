import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nmobile/common/chat/chat_out.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/media_picker.dart';
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
    if (source == ImageSource.camera) {
      String returnPath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: target, fileExt: 'jpg');
      File? result = await MediaPicker.takeCommon(
        bestSize: ChatOutCommon.imgBestSize,
        maxSize: ChatOutCommon.imgMaxSize,
        returnPath: returnPath,
      );
      if (result == null) return;
      onPicked?.call([
        {"path": result.absolute.path}
      ]);
    } else {
      int maxNum = 9;
      List<String> returnPaths = [];
      for (var i = 0; i < maxNum; i++) {
        String returnPath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: target, fileExt: 'jpg');
        returnPaths.add(returnPath);
      }
      List<Map<String, dynamic>> results = await MediaPicker.pickCommons(
        returnPaths,
        compressImage: false,
        compressVideo: false,
      );
      if (results.isEmpty) return;
      onPicked?.call(results);
    }
  }

  _pickFiles() async {
    if (!clientCommon.isClientCreated) return;
    FilePickerResult? result;
    try {
      // TODO:GG 选取预览？？？
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
      if (path == null || path.isEmpty) continue;
      String savePath = await Path.getRandomFile(clientCommon.getPublicKey(), DirType.chat, subPath: target, fileExt: picked.extension);
      await File(path).copy(savePath);
      results.add({
        "path": savePath,
        "size": picked.size,
        "fileExt": (picked.extension?.isEmpty != true) ? picked.extension : null,
      });
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
                    child: Asset.iconSvg(
                      'news', // TODO:GG icon 文件
                      width: iconSize,
                      color: application.theme.fontColor2,
                    ),
                    onPressed: () {
                      _pickFiles();
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
                  Global.locale((s) => s.pictures, ctx: context),
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

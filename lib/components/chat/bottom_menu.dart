import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/chat/chat_out.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/helpers/media_picker.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/path.dart';

class ChatBottomMenu extends StatelessWidget {
  String? target;
  bool show;
  final Function(File image)? onPickedImage;

  ChatBottomMenu({
    this.target,
    this.show = false,
    this.onPickedImage,
  });

  _getImageFile({required ImageSource source}) async {
    if (clientCommon.publicKey == null) return;
    String returnPath = await Path.getRandomFile(hexEncode(clientCommon.publicKey!), SubDirType.chat, target: target, fileExt: 'jpeg');
    File? picked = await MediaPicker.pickImage(
      source: source,
      maxSize: ChatOutCommon.imgSuggestSize,
      returnPath: returnPath,
    );
    if (picked == null) return;
    onPickedImage?.call(picked);
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
                      'image',
                      width: iconSize,
                      color: application.theme.fontColor2,
                    ),
                    onPressed: () {
                      _getImageFile(source: ImageSource.gallery);
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
                      _getImageFile(source: ImageSource.camera);
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/media_picker.dart';
import 'package:nmobile/utils/asset.dart';

class ChatBottomMenu extends StatelessWidget {
  bool show;
  Function(File image)? onPicked;

  ChatBottomMenu({
    this.show = false,
    this.onPicked,
  });

  _getImageFile({required ImageSource source}) async {
    File? picked = await MediaPicker.pick(
      source: source,
      mediaType: MediaType.image,
      compressQuality: 60,
    );
    if (picked == null) return;
    onPicked?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    double btnSize = MediaQuery.of(context).size.width / 6;
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
                  S.of(context).pictures,
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
                  S.of(context).camera,
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

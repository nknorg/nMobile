import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/utils/assets.dart';

class ChatBottomMenu extends StatelessWidget {
  bool show;

  ChatBottomMenu({this.show});

  _getImageFile({@required ImageSource source}) async {
    try {
      File image = await getCameraFile(chat.id, source: source);
      if (image != null) {
        // TODO
        // _sendImage(image);
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionLayout(
      isExpanded: show,
      child: Container(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: application.theme.backgroundColor2),
          ),
        ),
        child: Flex(
          direction: Axis.horizontal,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Expanded(
              flex: 0,
              child: Column(
                children: <Widget>[
                  SizedBox(
                    width: 71,
                    height: 71,
                    child: TextButton(
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.resolveWith((states) => application.theme.backgroundColor2),
                        shape: MaterialStateProperty.resolveWith((states) => RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)))),
                      ),
                      child: Asset.iconSvg(
                        'image',
                        width: 32,
                        color: application.theme.fontColor2,
                      ),
                      onPressed: () {
                        _getImageFile(source: ImageSource.gallery);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Label(
                      S.of(context).pictures,
                      type: LabelType.bodySmall,
                      color: application.theme.fontColor2,
                    ),
                  )
                ],
              ),
            ),
            Expanded(
              flex: 0,
              child: Column(
                children: <Widget>[
                  SizedBox(
                    width: 71,
                    height: 71,
                    child: TextButton(
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.resolveWith((states) => application.theme.backgroundColor2),
                        shape: MaterialStateProperty.resolveWith((states) => RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)))),
                      ),
                      child: Asset.iconSvg(
                        'camera',
                        width: 32,
                        color: application.theme.fontColor2,
                      ),
                      onPressed: () {
                        _getImageFile(source: ImageSource.camera);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Label(
                      S.of(context).camera,
                      type: LabelType.bodySmall,
                      color: application.theme.fontColor2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

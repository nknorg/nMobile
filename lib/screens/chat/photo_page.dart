import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_save/image_save.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:oktoast/oktoast.dart';

class PhotoPage extends StatefulWidget {
  static final String routeName = "PhotoPage";

  final String arguments;

  const PhotoPage({Key key, this.arguments}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return PhotoPageState();
  }
}

class PhotoPageState extends State<PhotoPage>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: Header(
        backgroundColor: Colors.black,
        hasBack: false,
        action: PopupMenuButton(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          icon: loadAssetIconsImage(
            'more',
            width: 24,
          ),
          onSelected: (int result) async {
            switch (result) {
              case 0:
                File file = File(widget.arguments);
                print(file.path);
                bool exist = await file.exists();
                if (exist) {
                  try {
                    String name = 'nkn_' +
                        DateTime.now().millisecondsSinceEpoch.toString();
                    final Uint8List bytes = await file.readAsBytes();
                    bool success = await ImageSave.saveImage(bytes, 'jpeg',
                        albumName: name);
                    if (success) {
                      showToast(NL10ns.of(context).success);
                    } else {
                      showToast(NL10ns.of(context).failure);
                    }
                  } catch (e) {
                    showToast(NL10ns.of(context).failure);
                  }
                } else {
                  showToast(NL10ns.of(context).failure);
                }
                break;
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
            PopupMenuItem<int>(
              value: 0,
              child: Label(
                NL10ns.of(context).save_to_album,
                type: LabelType.display,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: <Widget>[
          Container(
            padding: EdgeInsets.only(bottom: ScreenUtil.bottomBarHeight + 20.h),
            child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Center(
                    child: Hero(
                        tag: widget.arguments,
                        child: Image.file(
                          File(widget.arguments),
                        )))),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/utils/copy_utils.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ChatProfile extends StatefulWidget {
  static final String routeName = "ChatProfile";
  final ContactSchema arguments;
  ChatProfile({this.arguments});

  @override
  ChatProfileState createState() => new ChatProfileState();
}

class ChatProfileState extends State<ChatProfile> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        title: NL10ns.of(context).profile,
        backgroundColor: DefaultTheme.backgroundColor4,
      ),
      body: BodyBox(
        padding: const EdgeInsets.only(top: 4, left: 20, right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: FlatButton(
                padding: EdgeInsets.all(16),
                onPressed: () {
                  CopyUtils.copyAction(context, widget.arguments.clientAddress);
                },
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Label(
                          NL10ns.of(context).d_chat_address,
                          type: LabelType.bodyRegular,
                          color: DefaultTheme.fontColor1,
                          height: 1,
                        ),
                        Icon(
                          Icons.content_copy,
                          color: DefaultTheme.fontColor2,
                          size: 18,
                        )
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Label(
                            widget.arguments.clientAddress,
                            type: LabelType.bodyRegular,
                            color: DefaultTheme.fontColor2,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.all(10.w),
              child: Column(
                children: <Widget>[
//                  SizedBox(height: 30),
//                  widget.arguments.avatarWidget(
//                    backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(30),
//                    size: 24,
//                    fontColor: DefaultTheme.fontLightColor,
//                  ),
                  SizedBox(height: 20),
                  Center(
                    child: QrImage(
                      data: widget.arguments.clientAddress,
                      backgroundColor: DefaultTheme.backgroundLightColor,
                      foregroundColor: DefaultTheme.primaryColor,
                      version: QrVersions.auto,
                      size: 240.0,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Label(
                    NL10ns.of(context).scan_show_me_desc,
                    type: LabelType.bodyRegular,
                    color: DefaultTheme.fontColor2,
                    overflow: TextOverflow.fade,
                    textAlign: TextAlign.left,
                    height: 1,
                    softWrap: true,
                  ),
                  SizedBox(height: 20),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

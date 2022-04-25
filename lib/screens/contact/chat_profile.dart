import 'package:flutter/material.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/contact/avatar.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/util.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ContactChatProfileScreen extends StatefulWidget {
  static final String routeName = "/contact/chat_profile";
  static final String argContactSchema = "contact_schema";

  static Future go(BuildContext context, ContactSchema schema) {
    logger.d("ContactChatProfileScreen - go - schema:$schema");
    return Navigator.pushNamed(context, routeName, arguments: {
      argContactSchema: schema,
    });
  }

  final Map<String, dynamic>? arguments;

  ContactChatProfileScreen({Key? key, this.arguments}) : super(key: key);

  @override
  ContactChatProfileScreenState createState() => new ContactChatProfileScreenState();
}

class ContactChatProfileScreenState extends State<ContactChatProfileScreen> {
  late ContactSchema _contactSchema;

  @override
  void initState() {
    super.initState();
    _contactSchema = widget.arguments![ContactChatProfileScreen.argContactSchema];
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: Global.locale((s) => s.d_chat_address, ctx: context),
        backgroundColor: application.theme.backgroundColor4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 30, bottom: 30, left: 20, right: 20),
        child: Column(
          children: <Widget>[
            TextButton(
              style: ButtonStyle(
                padding: MaterialStateProperty.resolveWith((states) => EdgeInsets.all(16)),
                backgroundColor: MaterialStateProperty.resolveWith((states) => application.theme.backgroundLightColor),
                shape: MaterialStateProperty.resolveWith(
                  (states) => RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              onPressed: () {
                Util.copyText(this._contactSchema.clientAddress);
              },
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Label(
                        Global.locale((s) => s.d_chat_address, ctx: context),
                        type: LabelType.bodyRegular,
                        color: application.theme.fontColor1,
                      ),
                      Icon(
                        Icons.content_copy,
                        color: application.theme.fontColor2,
                        size: 18,
                      )
                    ],
                  ),
                  SizedBox(height: 10),
                  Label(
                    this._contactSchema.clientAddress,
                    type: LabelType.bodyRegular,
                    color: application.theme.fontColor2,
                    softWrap: true,
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.only(left: 16, right: 16, top: 30, bottom: 30),
              child: Column(
                children: <Widget>[
                  ContactAvatar(
                    contact: this._contactSchema,
                    radius: 24,
                  ),
                  SizedBox(height: 20),
                  this._contactSchema.clientAddress.isNotEmpty
                      ? Center(
                          child: QrImage(
                            data: this._contactSchema.clientAddress,
                            backgroundColor: application.theme.backgroundLightColor,
                            foregroundColor: application.theme.primaryColor,
                            version: QrVersions.auto,
                            size: 240.0,
                          ),
                        )
                      : SizedBox.shrink(),
                  SizedBox(height: 20),
                  Label(
                    Global.locale((s) => s.scan_show_me_desc, ctx: context),
                    type: LabelType.bodyRegular,
                    color: application.theme.fontColor2,
                    overflow: TextOverflow.fade,
                    textAlign: TextAlign.left,
                    softWrap: true,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/utils/util.dart';

class ContactMoreProfileScreen extends BaseStateFulWidget {
  static final String routeName = "/contact/more_profile";
  static final String argContactSchema = "contact_schema";

  static Future go(BuildContext? context, ContactSchema schema) {
    if (context == null) return Future.value(null);
    return Navigator.pushNamed(context, routeName, arguments: {
      argContactSchema: schema,
    });
  }

  final Map<String, dynamic>? arguments;

  ContactMoreProfileScreen({Key? key, this.arguments}) : super(key: key);

  @override
  ContactMoreProfileScreenState createState() => new ContactMoreProfileScreenState();
}

class ContactMoreProfileScreenState extends BaseStateFulWidgetState<ContactMoreProfileScreen> {
  late ContactSchema _contact;

  @override
  void initState() {
    super.initState();
  }

  @override
  void onRefreshArguments() {
    _contact = widget.arguments?[ContactMoreProfileScreen.argContactSchema];
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: Settings.locale((s) => s.profile, ctx: context),
        backgroundColor: application.theme.backgroundColor4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 30, bottom: 30, left: 20, right: 20),
        child: Column(
          children: <Widget>[
            // D-Chat Address card
            TextButton(
              style: ButtonStyle(
                padding: MaterialStateProperty.resolveWith((states) => EdgeInsets.all(16)),
                backgroundColor: MaterialStateProperty.resolveWith((states) => application.theme.backgroundLightColor),
                shape: MaterialStateProperty.resolveWith(
                  (states) => RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              onPressed: () {
                Util.copyText(this._contact.address);
                Toast.show(Settings.locale((s) => s.copied, ctx: context));
              },
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Label(
                        Settings.locale((s) => s.d_chat_address, ctx: context),
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
                    this._contact.address,
                    type: LabelType.bodyRegular,
                    color: application.theme.fontColor2,
                    softWrap: true,
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


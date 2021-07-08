import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/screens/contact/add.dart';
import 'package:nmobile/utils/asset.dart';

class ContactHomeEmptyLayout extends BaseStateFulWidget {
  @override
  _ContactHomeEmptyLayoutState createState() => _ContactHomeEmptyLayoutState();
}

class _ContactHomeEmptyLayoutState extends BaseStateFulWidgetState<ContactHomeEmptyLayout> {
  @override
  void onRefreshArguments() {}

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    double imgSize = Global.screenWidth() / 2;

    return Layout(
      headerColor: application.theme.primaryColor,
      header: Header(
        title: _localizations.my_contact,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, ContactAddScreen.routeName);
            },
            icon: Asset.iconSvg(
              'user-plus',
              // color: application.theme.backgroundLightColor,
              width: 24,
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Asset.image("contact/no-contact.png", width: imgSize, height: imgSize),
              SizedBox(height: 30),
              Column(
                children: <Widget>[
                  Label(
                    _localizations.contact_no_contact_title,
                    type: LabelType.h2,
                    textAlign: TextAlign.center,
                    maxLines: 10,
                  ),
                  SizedBox(height: 50),
                  Label(
                    _localizations.contact_no_contact_desc,
                    type: LabelType.bodySmall,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    maxLines: 10,
                  )
                ],
              ),
              SizedBox(height: 96),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Button(
                        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Asset.iconSvg('user-plus', color: application.theme.backgroundLightColor, width: 24),
                            SizedBox(width: 24),
                            Label(
                              _localizations.add_contact,
                              type: LabelType.h3,
                              color: application.theme.fontLightColor,
                            )
                          ],
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, ContactAddScreen.routeName);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

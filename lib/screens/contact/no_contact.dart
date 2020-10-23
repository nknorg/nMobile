import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nmobile/blocs/account_depends_bloc.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/screens/contact/add_contact.dart';
import 'package:nmobile/screens/contact/contact.dart';
import 'package:nmobile/utils/extensions.dart';

class NoContactScreen extends StatefulWidget {
  @override
  _NoContactScreenState createState() => _NoContactScreenState();
}

class _NoContactScreenState extends State<NoContactScreen> with AccountDependsBloc {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.primaryColor,
      appBar: Header(
        titleChild: GestureDetector(
          onTap: () async {
            accountUser.then((user) {
              Navigator.of(context).pushNamed(ContactScreen.routeName, arguments: user);
            });
          },
          child: accountUserBuilder(onUser: (ctx, user){
            return  Flex(
              direction: Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 0,
                  child: Container(
                    padding: const EdgeInsets.only(right: 16),
                    alignment: Alignment.center,
                    child: user.avatarWidget(db, backgroundColor: DefaultTheme.backgroundLightColor.withAlpha(200), size: 24),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Label(user.name, type: LabelType.h3, dark: true),
                      Label(NL10ns.of(context).click_to_settings, type: LabelType.bodyRegular, color: DefaultTheme.fontLightColor.withAlpha(200))
                    ],
                  ),
                )
              ],
            );
          }),
        ),
        backgroundColor: DefaultTheme.primaryColor,
        action: IconButton(
          icon: SvgPicture.asset(
            'assets/icons/user-plus.svg',
            color: DefaultTheme.backgroundLightColor,
            width: 24,
          ),
          onPressed: () {
            Navigator.pushNamed(context, AddContact.routeName);
          },
        ),
      ),
      body: Builder(
        builder: (BuildContext context) => BodyBox(
          padding: const EdgeInsets.only(top: 0, left: 20, right: 20),
          color: DefaultTheme.backgroundLightColor,
          child: SingleChildScrollView(
            child: Container(
              height: MediaQuery.of(context).size.height-MediaQuery.of(context).padding.top,
              child: Flex(
                direction: Axis.vertical,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    flex: 0,
                    child: Image(image: AssetImage("assets/contact/no-contact.png"), width: 198),
                  ),
                  Expanded(
                    flex: 0,
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.only(top: 32,bottom: 50),
                          child: Label(
                            NL10ns.of(context).contact_no_contact_title,
                            type: LabelType.h2,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(top: 8, left: 0, right: 0),
                          child: Label(
                            NL10ns.of(context).contact_no_contact_desc,
                            type: LabelType.bodySmall,
                            textAlign: TextAlign.center,
                            softWrap: true,
                          ),
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 0,
                    child: Column(
                      children: <Widget>[
                        Button(
                          width: -1,
                          height: 54,
                          padding: 0.pad(l: 36, r: 36),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              SvgPicture.asset('assets/icons/user-plus.svg', color: DefaultTheme.backgroundLightColor, width: 24).pad(r: 12),
                              Label(
                                NL10ns.of(context).add_contact,
                                type: LabelType.h3,
                              )
                            ],
                          ),
                          onPressed: () {
                            Navigator.pushNamed(context, AddContact.routeName);
                          },
                        ).pad(t: 96),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

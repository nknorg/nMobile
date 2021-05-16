import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/utils/assets.dart';

class ContactHomeEmptyLayout extends StatefulWidget {
  @override
  _ContactHomeEmptyLayoutState createState() => _ContactHomeEmptyLayoutState();
}

class _ContactHomeEmptyLayoutState extends State<ContactHomeEmptyLayout> {
  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    double imgSize = MediaQuery.of(context).size.width / 2;

    return Layout(
      header: Header(
        // TODO:GG need???
        // titleChild: GestureDetector(
        //   onTap: () async {
        //     ContactSchema currentUser = await ContactSchema.fetchCurrentUser();
        //     Navigator.of(context).pushNamed(ContactScreen.routeName, arguments: currentUser);
        //   },
        //   child: BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
        //     if (state is AuthToUserState) {
        //       ContactSchema currentUser = state.currentUser;
        //       return Flex(
        //         direction: Axis.horizontal,
        //         mainAxisAlignment: MainAxisAlignment.start,
        //         children: <Widget>[
        //           Expanded(
        //             flex: 0,
        //             child: Container(
        //               padding: const EdgeInsets.only(right: 16),
        //               alignment: Alignment.center,
        //               child: Container(
        //                 child: CommonUI.avatarWidget(
        //                   radiusSize: 28,
        //                   contact: currentUser,
        //                 ),
        //               ),
        //             ),
        //           ),
        //           Expanded(
        //             flex: 1,
        //             child: Column(
        //               crossAxisAlignment: CrossAxisAlignment.start,
        //               children: <Widget>[Label(currentUser.getShowName, type: LabelType.h3, dark: true), Label(NL10ns.of(context).click_to_settings, type: LabelType.bodyRegular, color: application.theme.fontLightColor.withAlpha(200))],
        //             ),
        //           )
        //         ],
        //       );
        //     }
        //     return Container();
        //   }),
        // ),
        actions: [
          IconButton(
            onPressed: () {
              // TODO:GG add
              // Navigator.pushNamed(context, AddContact.routeName);
            },
            // no effect ???
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
                          // TODO:GG add
                          // Navigator.pushNamed(context, AddContact.routeName);
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

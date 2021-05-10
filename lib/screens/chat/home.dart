import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nmobile/common/chat.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/screens/chat/message_list.dart';
import 'package:nmobile/screens/chat/no_connect.dart';
import 'package:nmobile/utils/assets.dart';

class ChatHomeScreen extends StatefulWidget {
  static const String routeName = '/chat/home';

  @override
  _ChatHomeScreenState createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> {
  _buttonStyle({bool top = false, bool bottom = false}) {
    return ButtonStyle(
      padding: MaterialStateProperty.resolveWith((states) => EdgeInsets.only(left: 16, right: 16)),
      shape: MaterialStateProperty.resolveWith(
        (states) => RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: top ? Radius.circular(12) : Radius.zero, bottom: bottom ? Radius.circular(12) : Radius.zero)),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    return StreamBuilder<int>(
      stream: chat.statusStream,
      initialData: chat.status,
      builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
        if (snapshot.data == ChatConnectStatus.disconnected) {
          return NoConnectScreen();
        } else {
          return Layout(
            header: Header(
              titleChild: Container(
                margin: EdgeInsets.only(left: 20),
                child: Flex(
                  direction: Axis.horizontal,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.red,
                        child: Label(
                          'HR',
                          type: LabelType.bodyLarge,
                          color: Colors.yellow,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Label('currentUser.getShowName', type: LabelType.h3, dark: true),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Label(_localizations.connect, type: LabelType.bodySmall, color: application.theme.fontLightColor.withAlpha(200)),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2, left: 4),
                                child: SpinKitThreeBounce(
                                  color: application.theme.fontLightColor.withAlpha(200),
                                  size: 10,
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
              actions: [Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: assetIcon('addbook', color: Colors.white, width: 24),
                  onPressed: () {
                    // todo
                    // if (TimerAuth.authed) {
                    //   Navigator.of(context).pushNamed(ContactHome.routeName);
                    // } else {
                    //   TimerAuth.instance.onCheckAuthGetPassword(context);
                    // }
                  },
                ),
              )],
            ),
            body: MessageListScreen(),
          );
        }
      },
    );
  }
}

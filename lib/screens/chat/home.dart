import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/locator.dart';
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
                      child: StreamBuilder<int>(
                        initialData: chat.status,
                        stream: chat.statusStream,
                        builder: (context, snapshot) {
                          Widget statusWidget = Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Label(_localizations.connecting, type: LabelType.h4, color: application.theme.fontLightColor.withAlpha(200)),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2, left: 4),
                                child: SpinKitThreeBounce(
                                  color: application.theme.fontLightColor.withAlpha(200),
                                  size: 10,
                                ),
                              ),
                            ],
                          );
                          switch(snapshot.data) {
                            case ChatConnectStatus.disconnected:
                              statusWidget = Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  Label(_localizations.disconnect, type: LabelType.h4, color: application.theme.strongColor),
                                ],
                              );
                              break;
                            case ChatConnectStatus.connected:
                              statusWidget = Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  Label(_localizations.connected, type: LabelType.h4, color: application.theme.successColor),
                                ],
                              );
                              break;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Label('currentUser.getShowName', type: LabelType.h3, dark: true),
                              statusWidget,
                            ],
                          );
                        }
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

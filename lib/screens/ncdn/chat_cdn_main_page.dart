import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/screens/ncdn/home.dart';
import 'package:nmobile/utils/image_utils.dart';

class ChatCDNMainPage extends StatefulWidget {
  static final String routeName = "ChatCDNMainPage";

  @override
  ChatCDNMainPageState createState() => new ChatCDNMainPageState();
}

class ChatCDNMainPageState extends State<ChatCDNMainPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: <Widget>[
          Container(
              decoration: BoxDecoration(
                color: DefaultTheme.backgroundLightColor,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Column(children: <Widget>[
                FlatButton(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12), bottom: Radius.circular(12))),
                  onPressed: () async {
                    Navigator.of(context).pushNamed(NcdnHomeScreen.routeName);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: <Widget>[
                        loadAssetWalletImage('pcdn_icon', width: 22),
                        SizedBox(width: 10),
                        Label(
                          'PCDN',
                          type: LabelType.bodyRegular,
                          color: DefaultTheme.fontColor1,
                          height: 1,
                        ),
                        Spacer(),
                        SvgPicture.asset(
                          'assets/icons/right.svg',
                          width: 24,
                          color: DefaultTheme.fontColor2,
                        ),
                      ],
                    ),
                  ),
                ),
              ]))
        ],
      ),
    );
  }
}

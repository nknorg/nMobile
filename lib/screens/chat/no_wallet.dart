import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/wallet/create_nkn_wallet.dart';
import 'package:nmobile/screens/wallet/import_nkn_eth_wallet.dart';
import 'package:nmobile/utils/image_utils.dart';

class NoWalletScreen extends StatefulWidget {
  static const String routeName = '/chat/no_wallet';

  @override
  _NoWalletScreenState createState() => _NoWalletScreenState();
}

class _NoWalletScreenState extends State<NoWalletScreen> {
  final GetIt locator = GetIt.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.primaryColor,
      appBar: Header(
        titleChild: Padding(
          // It is consistent with other pages, and I read its source code, but it is not so adapted.
          padding: EdgeInsets.only(left: 20),
          child: Label(
            NL10ns.of(context).menu_chat.toUpperCase(),
            type: LabelType.h2,
          ),
        ),
        hasBack: false,
        backgroundColor: DefaultTheme.primaryColor,
        leading: null,
      ),
      body: Builder(
        builder: (BuildContext context) => BodyBox(
          padding: EdgeInsets.only(top: 0, left: 20.w, right: 20.w, bottom: 100.h),
          color: DefaultTheme.backgroundColor1,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(),
                  child: loadAssetChatPng('messages', width: 198.w, height: 144.h),
                ),
                Expanded(
                  flex: 0,
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(top: 32),
                        child: Label(
                          NL10ns.of(context).chat_no_wallet_title,
                          type: LabelType.h2,
                          textAlign: TextAlign.center,
                          softWrap: true,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 8, left: 48, right: 48),
                        child: Label(
                          NL10ns.of(context).chat_no_wallet_desc,
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
                      Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Button(
                          text: NL10ns.of(context).no_wallet_create,
                          onPressed: () {
                            Navigator.pushNamed(context, CreateNknWalletScreen.routeName);
                          },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Button(
                          text: NL10ns.of(context).no_wallet_import,
                          backgroundColor: DefaultTheme.primaryColor.withAlpha(20),
                          fontColor: DefaultTheme.primaryColor,
                          onPressed: () {
                            Navigator.pushNamed(context, ImportWalletScreen.routeName, arguments: WalletType.nkn);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

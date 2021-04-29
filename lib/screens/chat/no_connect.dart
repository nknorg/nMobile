import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/wallet/dropdown.dart';
import 'package:nmobile/components/wallet/item.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';

class NoConnectScreen extends StatefulWidget {
  @override
  _NoConnectScreenState createState() => _NoConnectScreenState();
}

class _NoConnectScreenState extends State<NoConnectScreen> {
  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    return Layout(
      headerColor: application.theme.primaryColor,
      header: Header(
        titleChild: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Label(
            _localizations.menu_chat,
            type: LabelType.h2,
            color: application.theme.fontLightColor,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Flex(
          direction: Axis.vertical,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 0,
              child: Image(image: AssetImage("assets/chat/messages.png"), width: 198, height: 144),
            ),
            Expanded(
              flex: 0,
              child: Padding(
                padding: const EdgeInsets.only(top: 30, bottom: 20),
                child: Column(
                  children: [
                    Label(
                      _localizations.chat_no_wallet_title,
                      type: LabelType.h2,
                      textAlign: TextAlign.center,
                    ),
                    Label(
                      _localizations.click_connect,
                      type: LabelType.bodyRegular,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 0,
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
                child: WalletDropdown(
                  schema: WalletSchema(),
                ),
              ),
            ),
            Expanded(
              flex: 0,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Button(
                      width: double.infinity,
                      text: _localizations.connect,
                      onPressed: () {},
                    ),
                  )
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}

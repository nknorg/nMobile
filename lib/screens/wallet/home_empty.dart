import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/screens/wallet/create_nkn.dart';
import 'package:nmobile/utils/assets.dart';

class WalletHomeEmpty extends StatefulWidget {
  @override
  _WalletHomeEmptyState createState() => _WalletHomeEmptyState();
}

class _WalletHomeEmptyState extends State<WalletHomeEmpty> {
  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    return Layout(
      headerColor: application.theme.primaryColor,
      header: Header(
        titleChild: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Label(
            _localizations.menu_wallet,
            type: LabelType.h2,
            color: application.theme.fontLightColor,
          ),
        ),
      ),
      child: Container(
        color: application.theme.backgroundColor,
        constraints: BoxConstraints.expand(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              flex: 0,
              child: Container(
                // color: Colors.amberAccent,
                child: Padding(
                  padding: EdgeInsets.only(),
                  child: assetImage("wallet/pig.png", width: 120),
                ),
              ),
            ),
            Expanded(
              flex: 0,
              child: Container(
                // color: Colors.green,
                child: Column(
                  children: <Widget>[
                    Label(_localizations.no_wallet_title, type: LabelType.h2, dark: true, textAlign: TextAlign.center),
                    Padding(
                      padding: EdgeInsets.only(top: 16, left: 24, right: 24),
                      child: Label(_localizations.no_wallet_desc, type: LabelType.h4, dark: true, softWrap: true, textAlign: TextAlign.center),
                    )
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 0,
              child: Container(
                // color: Colors.red,
                child: Column(
                  children: <Widget>[
                    Button(
                      text: _localizations.no_wallet_create,
                      onPressed: () {
                        Navigator.pushNamed(context, WalletCreateNKN.routeName);
                      },
                    ),
                    Button(
                      text: _localizations.no_wallet_import,
                      backgroundColor: Color(0xFF232D50),
                      onPressed: () {
                        // TODO:GG route_wallet_import
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

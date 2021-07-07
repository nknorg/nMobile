import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/wallet/create_nkn.dart';
import 'package:nmobile/screens/wallet/import.dart';
import 'package:nmobile/utils/asset.dart';

class WalletHomeEmptyLayout extends BaseStateFulWidget {
  @override
  _WalletHomeEmptyLayoutState createState() => _WalletHomeEmptyLayoutState();
}

class _WalletHomeEmptyLayoutState extends BaseStateFulWidgetState<WalletHomeEmptyLayout> {
  @override
  void onRefreshArguments() {}

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    return Container(
      color: application.theme.backgroundColor4,
      padding: EdgeInsets.fromLTRB(20, 32, 20, 86),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Center(
            child: Asset.image("wallet/pig.png", width: Global.screenWidth / 3),
          ),
          Expanded(
            flex: 0,
            child: Column(
              children: <Widget>[
                Label(
                  _localizations.no_wallet_title,
                  color: application.theme.fontLightColor,
                  type: LabelType.h2,
                  dark: true,
                  textAlign: TextAlign.center,
                ),
                Padding(
                  padding: EdgeInsets.only(top: 16, left: 24, right: 24),
                  child: Label(
                    _localizations.no_wallet_desc,
                    color: application.theme.fontLightColor,
                    type: LabelType.h4,
                    dark: true,
                    softWrap: true,
                    textAlign: TextAlign.center,
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
                  text: _localizations.no_wallet_create,
                  width: double.infinity,
                  fontColor: application.theme.fontLightColor,
                  backgroundColor: application.theme.primaryColor,
                  onPressed: () {
                    WalletCreateNKNScreen.go(context);
                  },
                ),
                SizedBox(height: 12),
                Button(
                  text: _localizations.no_wallet_import,
                  width: double.infinity,
                  fontColor: application.theme.fontLightColor,
                  backgroundColor: application.theme.primaryColor.withAlpha(20),
                  onPressed: () {
                    WalletImportScreen.go(context, WalletType.nkn);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

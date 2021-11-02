import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/wallet/dropdown.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/wallet/create_nkn.dart';
import 'package:nmobile/screens/wallet/import.dart';
import 'package:nmobile/utils/asset.dart';

class ChatNoConnectLayout extends BaseStateFulWidget {
  final Function(WalletSchema? wallet)? goConnect;

  ChatNoConnectLayout(this.goConnect);

  @override
  _ChatNoConnectLayoutState createState() => _ChatNoConnectLayoutState();
}

class _ChatNoConnectLayoutState extends BaseStateFulWidgetState<ChatNoConnectLayout> {
  WalletBloc? _walletBloc;
  StreamSubscription? _walletAddSubscription;

  bool loaded = false;
  WalletSchema? _selectWallet;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
    // wallet
    _walletBloc = BlocProvider.of<WalletBloc>(this.context);
    _walletAddSubscription = _walletBloc?.stream.listen((event) {
      _refreshWalletDefault();
    });

    // default
    _refreshWalletDefault();
  }

  @override
  void dispose() {
    _walletAddSubscription?.cancel();
    super.dispose();
  }

  _refreshWalletDefault() async {
    WalletSchema? _defaultSelect = await walletCommon.getDefault();
    if (_defaultSelect == null) {
      List<WalletSchema> wallets = await walletCommon.getWallets();
      if (wallets.isNotEmpty) {
        _defaultSelect = wallets[0];
      }
    }
    setState(() {
      loaded = true;
      _selectWallet = _defaultSelect;
    });
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    double headImageWidth = Global.screenWidth() * 0.55;
    double headImageHeight = headImageWidth / 3 * 2;

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 60, bottom: 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Asset.image(
              'chat/messages.png',
              width: headImageWidth,
              height: headImageHeight,
            ),
            SizedBox(height: 50),
            Column(
              children: [
                Label(
                  _localizations.chat_no_wallet_title,
                  type: LabelType.h2,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 5),
                Label(
                  _localizations.click_connect,
                  type: LabelType.bodyRegular,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            SizedBox(height: 30),
            this._selectWallet == null || !loaded
                ? SizedBox(height: 30)
                : Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
                    child: WalletDropdown(
                      onTapWave: false,
                      onSelected: (v) {
                        setState(() {
                          _selectWallet = v;
                        });
                      },
                      wallet: this._selectWallet!,
                      onlyNKN: true,
                    ),
                  ),
            SizedBox(height: 20),
            !loaded
                ? SizedBox.shrink()
                : this._selectWallet == null
                    ? Column(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Button(
                              text: _localizations.no_wallet_create,
                              width: double.infinity,
                              fontColor: application.theme.fontLightColor,
                              backgroundColor: application.theme.primaryColor,
                              onPressed: () {
                                WalletCreateNKNScreen.go(context);
                              },
                            ),
                          ),
                          SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Button(
                              text: _localizations.no_wallet_import,
                              width: double.infinity,
                              fontColor: application.theme.fontLightColor,
                              backgroundColor: application.theme.primaryColor.withAlpha(80),
                              onPressed: () {
                                WalletImportScreen.go(context, WalletType.nkn);
                              },
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Button(
                              width: double.infinity,
                              text: _localizations.connect,
                              onPressed: () {
                                if (this._selectWallet?.type != WalletType.nkn) return;
                                this.widget.goConnect?.call(this._selectWallet);
                              },
                            ),
                          )
                        ],
                      ),
          ],
        ),
      ),
    );
  }
}

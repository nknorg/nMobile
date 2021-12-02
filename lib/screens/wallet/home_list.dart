import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/blocs/settings/settings_bloc.dart';
import 'package:nmobile/blocs/settings/settings_state.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_state.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/wallet/erc20.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/components/wallet/item.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/wallet/create_eth.dart';
import 'package:nmobile/screens/wallet/create_nkn.dart';
import 'package:nmobile/screens/wallet/detail.dart';
import 'package:nmobile/screens/wallet/export.dart';
import 'package:nmobile/screens/wallet/import.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';

class WalletHomeListLayout extends BaseStateFulWidget {
  @override
  _WalletHomeListLayoutState createState() => _WalletHomeListLayoutState();
}

class _WalletHomeListLayoutState extends BaseStateFulWidgetState<WalletHomeListLayout> with Tag {
  StreamSubscription? _settingSubscription;

  WalletBloc? _walletBloc;
  StreamSubscription? _walletSubscription;

  bool _allBackedUp = true;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
    // balance query
    walletCommon.queryBalance(delayMs: 2000); // await

    // settings
    SettingsBloc _settingsBloc = BlocProvider.of<SettingsBloc>(context);
    _settingSubscription = _settingsBloc.stream.listen((state) async {
      if (state is LocaleUpdated) {
        Future.delayed(Duration(milliseconds: 500), () => setState(() {}));
      }
    });

    // wallet
    _walletBloc = BlocProvider.of<WalletBloc>(context);
    _walletSubscription = _walletBloc?.stream.listen((state) async {
      if (state is WalletLoaded) {
        _refreshBackedUp();
      }
    });

    // init
    _refreshBackedUp();
  }

  @override
  void dispose() {
    _settingSubscription?.cancel();
    _walletSubscription?.cancel();
    super.dispose();
  }

  _refreshBackedUp() async {
    List<WalletSchema> wallets = await walletCommon.getWallets();
    List<WalletSchema> noBackedUpList = wallets.where((element) => element.isBackedUp == false).toList();
    bool allBackedUp = noBackedUpList.isEmpty;
    if (allBackedUp != _allBackedUp) {
      setState(() {
        _allBackedUp = allBackedUp;
      });
    }
  }

  _onNotBackedUpTipClicked() {
    ModalDialog dialog = ModalDialog.of(Global.appContext);
    dialog.show(
      title: Global.locale((s) => s.d_not_backed_up_title),
      content: Global.locale((s) => s.d_not_backed_up_desc),
      hasCloseButton: false,
      actions: [
        Button(
          text: Global.locale((s) => s.go_backup, ctx: context),
          width: double.infinity,
          onPressed: () async {
            await dialog.close();
            WalletSchema? result = await BottomDialog.of(Global.appContext).showWalletSelect(title: Global.locale((s) => s.select_asset_to_backup, ctx: context));
            _readyExport(result);
          },
        ),
      ],
    );
  }

  _readyExport(WalletSchema? schema) {
    logger.i("$TAG - backup picked - $schema");
    if (schema == null || schema.address.isEmpty) return;

    authorization.getWalletPassword(schema.address).then((String? password) async {
      if (password == null || password.isEmpty) return;
      String keystore = await walletCommon.getKeystore(schema.address);

      Loading.show();
      if (schema.type == WalletType.eth) {
        final eth = await Ethereum.restoreByKeyStore(name: schema.name ?? "", keystore: keystore, password: password);
        String ethAddress = (await eth.address).hex;
        String ethKeystore = await eth.keystore();
        Loading.dismiss();

        if (ethAddress.isEmpty || ethKeystore.isEmpty || ethAddress != schema.address) {
          Toast.show(Global.locale((s) => s.password_wrong));
          return;
        }

        WalletExportScreen.go(
          context,
          WalletType.eth,
          schema.name ?? "",
          ethAddress,
          eth.pubKeyHex,
          eth.privateKeyHex,
          ethKeystore,
        );
      } else {
        List<String> seedRpcList = await Global.getRpcServers(null, measure: true);
        Wallet nkn = await Wallet.restore(keystore, config: WalletConfig(password: password, seedRPCServerAddr: seedRpcList));
        Loading.dismiss();

        if (nkn.address.isEmpty || nkn.address != schema.address) {
          Toast.show(Global.locale((s) => s.password_wrong));
          return;
        }

        WalletExportScreen.go(
          context,
          WalletType.nkn,
          schema.name,
          nkn.address,
          hexEncode(nkn.publicKey),
          hexEncode(nkn.seed),
          nkn.keystore,
        );
      }
    }).onError((error, stackTrace) {
      Loading.dismiss();
      handleError(error, stackTrace: stackTrace);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      // floatingActionButton: FloatingActionButton(onPressed: () => LocalStorage().debugInfo()), // test
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerTop, // test
      headerColor: application.theme.primaryColor,
      header: Header(
        titleChild: Padding(
          padding: EdgeInsets.only(left: 20),
          child: Label(
            Global.locale((s) => s.my_wallets, ctx: context),
            type: LabelType.h2,
            color: application.theme.fontLightColor,
          ),
        ),
        childTail: _allBackedUp
            ? SizedBox.shrink()
            : TextButton(
                onPressed: _onNotBackedUpTipClicked,
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.warning_rounded,
                      color: Color(0xFFF5B800),
                      size: 20,
                    ),
                    SizedBox(width: 4),
                    Text(
                      Global.locale((s) => s.not_backed_up, ctx: context),
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: application.theme.bodyText3.fontSize, color: application.theme.strongColor),
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      maxLines: 1,
                    ),
                  ],
                ),
                // onPressed: _onNotBackedUpTipClicked,
              ),
        actions: [
          PopupMenuButton(
            icon: Asset.iconSvg('more', width: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onSelected: (int result) async {
              String? walletType = await BottomDialog.of(Global.appContext).showWalletTypeSelect(
                title: Global.locale((s) => s.select_wallet_type),
                desc: Global.locale((s) => s.select_wallet_type_desc),
              );
              switch (result) {
                case 0:
                  // create
                  if (walletType == WalletType.nkn) {
                    WalletCreateNKNScreen.go(context);
                  } else if (walletType == WalletType.eth) {
                    WalletCreateETHScreen.go(context);
                  }
                  break;
                case 1:
                  // import
                  if (walletType == WalletType.nkn || walletType == WalletType.eth) {
                    WalletImportScreen.go(context, walletType!);
                  }
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
              PopupMenuItem<int>(
                value: 0,
                child: Label(
                  Global.locale((s) => s.no_wallet_create, ctx: context),
                  type: LabelType.display,
                ),
              ),
              PopupMenuItem<int>(
                value: 1,
                child: Label(
                  Global.locale((s) => s.import_wallet, ctx: context),
                  type: LabelType.display,
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocBuilder<WalletBloc, WalletState>(
        builder: (context, state) {
          if (state is WalletLoaded) {
            return ListView.builder(
              padding: EdgeInsets.only(top: 22, bottom: 80 + Global.screenHeight() * 0.05),
              itemCount: state.wallets.length,
              itemBuilder: (context, index) {
                if (index < 0 || index >= state.wallets.length) return SizedBox.shrink();
                WalletSchema wallet = state.wallets[index];
                // if (index == 1) wallet.type = WalletType.eth; // test
                return Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
                  child: WalletItem(
                    wallet: wallet,
                    walletType: wallet.type,
                    onTap: () {
                      WalletDetailScreen.go(context, wallet, listIndex: index);
                    },
                    bgColor: application.theme.backgroundLightColor,
                    radius: BorderRadius.circular(8),
                  ),
                );
              },
            );
          }
          return SizedBox.shrink();
        },
      ),
    );
  }
}

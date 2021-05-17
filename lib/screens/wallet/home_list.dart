import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart' as WalletSDK;
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/components/wallet/item.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/asset.dart';
import 'package:nmobile/helpers/logger.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/wallet/create_eth.dart';
import 'package:nmobile/screens/wallet/create_nkn.dart';
import 'package:nmobile/screens/wallet/detail.dart';
import 'package:nmobile/screens/wallet/import.dart';
import 'package:nmobile/services/task_service.dart';
import 'package:nmobile/utils/error.dart';

import 'export.dart';

class WalletHomeListLayout extends StatefulWidget {
  @override
  _WalletHomeListLayoutState createState() => _WalletHomeListLayoutState();
}

class _WalletHomeListLayoutState extends State<WalletHomeListLayout> {
  WalletBloc _walletBloc;
  StreamSubscription _walletSubscription;

  bool _allBackedUp = false;

  @override
  void initState() {
    super.initState();
    // balance query
    locator<TaskService>().queryWalletBalanceTask();

    _walletBloc = BlocProvider.of<WalletBloc>(context);

    // backup
    _walletSubscription = _walletBloc.stream.listen((state) async {
      // if (state is WalletBackup) {
      //   setState(() {
      //     _allBackedUp = state.allBackup ?? false;
      //   });
      // }
      if (state is WalletLoaded) {
        _allBackedUp = await wallet.isWalletsBackup();
        setState(() {});
      }
    });
    wallet.isWalletsBackup().then((value) {
      if (mounted) {
        setState(() {
          _allBackedUp = value ?? false;
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _walletSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);

    return Layout(
      // floatingActionButton: FloatingActionButton(onPressed: () => LocalStorage().debugInfo()), // test
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerTop, // test
      header: Header(
        titleChild: Padding(
          padding: EdgeInsets.only(left: 20),
          child: Label(
            _localizations.my_wallets,
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
                      _localizations.not_backed_up,
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
              final walletType = await BottomDialog.of(context).showWalletTypeSelect(
                title: _localizations.select_wallet_type,
                desc: _localizations.select_wallet_type_desc,
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
                    WalletImportScreen.go(context, walletType);
                  }
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
              PopupMenuItem<int>(
                value: 0,
                child: Label(
                  _localizations.no_wallet_create,
                  type: LabelType.display,
                ),
              ),
              PopupMenuItem<int>(
                value: 1,
                child: Label(
                  _localizations.import_wallet,
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
              padding: EdgeInsets.only(top: 22, bottom: 86),
              itemCount: state.wallets?.length ?? 0,
              itemBuilder: (context, index) {
                WalletSchema wallet = state.wallets[index];
                // if (index == 1) wallet.type = WalletType.eth; // test
                return Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
                  child: WalletItem(
                    schema: wallet,
                    type: wallet.type,
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

  _onNotBackedUpTipClicked() {
    S _localizations = S.of(context);
    ModalDialog dialog = ModalDialog.of(context);
    dialog.show(
      title: _localizations.d_not_backed_up_title,
      content: _localizations.d_not_backed_up_desc,
      hasCloseIcon: false,
      hasCloseButton: false,
      actions: [
        Button(
          text: _localizations.go_backup,
          width: double.infinity,
          onPressed: () async {
            await dialog.close();
            WalletSchema result = await BottomDialog.of(context).showWalletSelect(title: _localizations.select_asset_to_backup);
            _readyExport(result);
          },
        ),
      ],
    );
  }

  _readyExport(WalletSchema scheme) {
    logger.d("backup picked - $scheme");
    if (scheme == null || scheme.address == null || scheme.address.isEmpty) return;
    S _localizations = S.of(context);

    wallet.getWalletPassword(context, scheme?.address).then((String password) async {
      if (password == null || password.isEmpty) {
        // no toast
        return;
      }
      String keystore = await wallet.getWalletKeystoreByAddress(scheme.address);

      if (scheme.type == WalletType.eth) {
        // TODO:GG eth export
        // String keyStore = await ws.getKeystore();
        // EthWallet ethWallet = Ethereum.restoreWallet(
        //     name: ws.name, keystore: keyStore, password: password);
        // Navigator.of(context)
        //     .pushNamed(NknWalletExportScreen.routeName, arguments: {
        //   'wallet': null,
        //   'keystore': ethWallet.keystore,
        //   'address': (await ethWallet.address).hex,
        //   'publicKey': ethWallet.pubkeyHex,
        //   'seed': ethWallet.privateKeyHex,
        //   'name': ethWallet.name,
        // });
      } else {
        WalletSDK.Wallet restore = await WalletSDK.Wallet.restore(keystore, config: WalletSDK.WalletConfig(password: password));
        if (restore == null || restore.address != scheme.address) {
          Toast.show(_localizations.password_wrong);
          return;
        }

        WalletExportScreen.go(
          context,
          WalletType.nkn,
          scheme.name,
          restore.address,
          hexEncode(restore.publicKey ?? ""),
          hexEncode(restore.seed ?? ""),
          restore.keystore,
        );
      }
    }).onError((error, stackTrace) {
      handleError(error, stackTrace: stackTrace);
    });
  }
}

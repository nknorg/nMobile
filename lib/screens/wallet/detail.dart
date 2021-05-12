import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/components/wallet/avatar.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/wallet/export.dart';
import 'package:nmobile/storages/wallet.dart';
import 'package:nmobile/utils/assets.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/utils.dart';

import '../../app.dart';

class WalletDetailScreen extends StatefulWidget {
  static const String routeName = '/wallet/detail_nkn';
  static final String argWallet = "wallet";
  // static final String argListIndex = "list_index";

  final Map<String, dynamic> arguments;

  const WalletDetailScreen({Key key, this.arguments}) : super(key: key);

  @override
  _WalletDetailScreenState createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  WalletSchema _wallet;
  // int _listIndex;

  WalletBloc _walletBloc;
  // NKNClientBloc _clientBloc;
  bool isDefault = false;

  @override
  void initState() {
    super.initState();
    this._wallet = widget.arguments[WalletDetailScreen.argWallet];
    // this._listIndex = widget.arguments[WalletDetailScreen.argListIndex];

    _walletBloc = BlocProvider.of<WalletBloc>(context);
    // _clientBloc = BlocProvider.of<NKNClientBloc>(context);
    // TODO:GG default wallet
    // widget.wallet.isDefaultWallet().then((v) {
    //   if (mounted) {
    //     setState(() {
    //       isDefault = v;
    //     });
    //   }
    // });

    // TimerAuth.onOtherPage = true; // TODO:GG wallet lock
  }

  @override
  void dispose() {
    super.dispose();
    // TimerAuth.onOtherPage = false; // TODO:GG wallet unlock
  }

  // TODO:GG receive
  _receive() {
    // Navigator.of(context).pushNamed(ReceiveNknScreen.routeName, arguments: widget.wallet);
  }

  // TODO:GG send
  _send() {
    // Navigator.of(context)
    //     .pushNamed(
    //   widget.wallet.type == WalletSchema.ETH_WALLET ? SendErc20Screen.routeName : SendNknScreen.routeName,
    //   arguments: widget.wallet,
    // )
    //     .then((FutureOr success) async {
    //   if (success != null && await success) {
    //     NotificationDialog.of(context).show(
    //       title: _localizations.transfer_initiated,
    //       content: _localizations.transfer_initiated_desc,
    //     );
    //   }
    // });
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);

    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: isDefault ? _localizations.main_wallet : (this._wallet?.name?.toUpperCase() ?? ""),
        backgroundColor: application.theme.backgroundColor4,
        actions: [
          PopupMenuButton(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            icon: assetIcon('more', width: 24),
            onSelected: (int result) {
              _onAppBarActionSelected(result);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
              PopupMenuItem<int>(
                value: 0,
                child: Label(_localizations.export_wallet, type: LabelType.display),
              ),
              PopupMenuItem<int>(
                value: 1,
                child: Label(
                  _localizations.delete_wallet,
                  type: LabelType.display,
                  color: application.theme.strongColor,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            SizedBox(height: 12),
            Hero(
              tag: 'avatar:${this._wallet?.address}',
              child: WalletAvatar(
                width: 60,
                height: 60,
                walletType: this._wallet?.type,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                ethTop: 16,
                ethRight: 12,
              ),
            ),
            BlocBuilder<WalletBloc, WalletState>(
              builder: (context, state) {
                if (state is WalletLoaded) {
                  this._wallet = state.getWalletByAddress(this._wallet?.address);
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _wallet != null ? Label(nknFormat(_wallet?.balance ?? 0, decimalDigits: 4), type: LabelType.h1) : Label('--', type: LabelType.h1),
                          Label('NKN', type: LabelType.bodySmall, color: application.theme.fontColor1), // .pad(t: 4),
                        ],
                      ),
                      _wallet != null && _wallet.type == WalletType.eth
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Label(nknFormat(_wallet.balanceEth ?? 0, decimalDigits: 4), type: LabelType.bodySmall),
                                Padding(
                                  padding: const EdgeInsets.only(left: 6, right: 2),
                                  child: Label('ETH', type: LabelType.bodySmall, color: application.theme.fontColor1),
                                ),
                              ],
                            )
                          : SizedBox.shrink(),
                    ],
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 40),
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 1,
                    child: Button(
                      text: _localizations.send,
                      onPressed: _send,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: Button(
                      text: _localizations.receive,
                      onPressed: _receive,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: <Widget>[
                Material(
                  color: application.theme.backgroundColor1,
                  elevation: 0,
                  child: InkWell(
                    onTap: () {
                      _showChangeNameDialog();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Label(
                                _localizations.wallet_name,
                                type: LabelType.h3,
                                textAlign: TextAlign.start,
                              ),
                            ],
                          ),
                          SizedBox(height: 15),
                          Label(
                            this._wallet?.name ?? "",
                            type: LabelType.display,
                          ),
                          SizedBox(height: 15),
                          Divider(height: 1),
                        ],
                      ),
                    ),
                  ),
                ),
                Material(
                  color: application.theme.backgroundColor1,
                  elevation: 0,
                  child: InkWell(
                    onTap: () {
                      copyText(this._wallet?.address, context: context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Label(
                                _localizations.wallet_address,
                                type: LabelType.h3,
                                textAlign: TextAlign.start,
                              ),
                              Label(
                                _localizations.copy,
                                color: application.theme.primaryColor,
                                type: LabelType.bodyLarge,
                              ),
                            ],
                          ),
                          SizedBox(height: 15),
                          Label(this._wallet?.address ?? "", type: LabelType.display),
                          SizedBox(height: 15),
                          Divider(height: 1),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _showChangeNameDialog() async {
    S _localizations = S.of(context);
    String newName = await BottomDialog.of(context).showInput(
      title: _localizations.wallet_name,
      inputTip: _localizations.hint_enter_wallet_name,
      inputHint: _localizations.hint_enter_wallet_name,
      actionText: _localizations.save,
      maxLength: 20,
    );
    if (newName == null || newName.isEmpty) return;
    setState(() {
      this._wallet.name = newName; // update appBar title
    });
    _walletBloc?.add(UpdateWallet(this._wallet));
  }

  _onAppBarActionSelected(int result) async {
    S _localizations = S.of(context);
    WalletStorage _storage = WalletStorage();

    switch (result) {
      case 0: // export
        Future(() async {
          if (Settings.biometricsAuthentication) {
            return authorization.authenticationIfCan();
          }
          return false;
        }).then((bool authOk) async {
          if (!authOk) {
            return BottomDialog.of(context).showInput(
              title: _localizations.verify_wallet_password,
              inputTip: _localizations.wallet_password,
              inputHint: _localizations.input_password,
              actionText: _localizations.continue_text,
              password: true,
            );
          }
          return _storage.getPassword(_wallet?.address);
        }).then((password) async {
          if (password == null || password.isEmpty) {
            return;
          }
          String keystore = await _storage.getKeystore(_wallet.address);

          if (_wallet.type == WalletType.eth) {
            // TODO:GG eth export
            // final ethWallet = await Ethereum.restoreWalletSaved(
            //     schema: widget.wallet, password: password);
            //
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
            Wallet restore = await Wallet.restore(keystore, config: WalletConfig(password: password));
            if (restore == null || restore.address != _wallet.address) {
              Toast.show(_localizations.password_wrong);
              return;
            }

            // TimerAuth.instance.enableAuth(); // TODO:GG auth?

            Navigator.pushNamed(context, WalletExportScreen.routeName, arguments: {
              WalletExportScreen.argWalletType: WalletType.nkn,
              WalletExportScreen.argName: _wallet.name ?? "",
              WalletExportScreen.argAddress: restore.address ?? "",
              WalletExportScreen.argPublicKey: hexEncode(restore.publicKey ?? ""),
              WalletExportScreen.argSeed: hexEncode(restore.seed ?? ""),
              WalletExportScreen.argKeystore: restore.keystore ?? "",
            });
          }
        }).onError((error, stackTrace) {
          logger.e(error);
        });
        break;
      case 1: // delete
        ModalDialog.of(context).confirm(
          title: _localizations.delete_wallet_confirm_title,
          content: _localizations.delete_wallet_confirm_text,
          agree: Button(
            text: _localizations.delete_wallet,
            backgroundColor: application.theme.strongColor,
            width: double.infinity,
            onPressed: () async {
              _walletBloc.add(DeleteWallet(this._wallet));
              // TODO:GG client check (default wallet)
              // if (NKNClientCaller.currentChatId != null) {
              //   var walletAddr = await NknWalletPlugin.pubKeyToWalletAddr(NKNClientCaller.currentChatId);
              //   if (walletAddr == widget.wallet.address) {
              //     NLog.d('delete client');
              //     _clientBloc.add(NKNDisConnectClientEvent());
              //   } else {
              //     NLog.d('no delete client');
              //   }
              // }
              Navigator.popAndPushNamed(context, AppScreen.routeName);
            },
          ),
          reject: Button(
            text: _localizations.cancel,
            backgroundColor: application.theme.backgroundLightColor,
            fontColor: application.theme.fontColor2,
            width: double.infinity,
            onPressed: () => Navigator.pop(context),
          ),
        );
        break;
    }
  }
}

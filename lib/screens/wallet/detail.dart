import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/dialog/notification.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/components/wallet/avatar.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/wallet/export.dart';
import 'package:nmobile/screens/wallet/receive.dart';
import 'package:nmobile/screens/wallet/send.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/utils.dart';

class WalletDetailScreen extends BaseStateFulWidget {
  static const String routeName = '/wallet/detail_nkn';
  static final String argWallet = "wallet";
  static final String argListIndex = "list_index";

  static Future go(BuildContext context, WalletSchema wallet, {int? listIndex}) {
    logger.d("WalletDetailScreen - go - $wallet");
    return Navigator.pushNamed(context, routeName, arguments: {
      argWallet: wallet,
      argListIndex: listIndex,
    });
  }

  final Map<String, dynamic>? arguments;

  const WalletDetailScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _WalletDetailScreenState createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends BaseStateFulWidgetState<WalletDetailScreen> {
  WalletSchema? _wallet;

  WalletBloc? _walletBloc;
  StreamSubscription? _walletSubscription;

  bool isDefault = false;

  @override
  void onRefreshArguments() {
    this._wallet = widget.arguments![WalletDetailScreen.argWallet];
  }

  @override
  void initState() {
    super.initState();
    _walletBloc = BlocProvider.of<WalletBloc>(context);

    // default
    _walletSubscription = _walletBloc?.stream.listen((state) {
      if (state is WalletDefault) {
        setState(() {
          isDefault = state.walletAddress == _wallet?.address;
        });
      }
    });
    walletCommon.getDefaultAddress().then((value) {
      setState(() {
        isDefault = value == _wallet?.address;
      });
    });

    // TimerAuth.onOtherPage = true; // TODO:GG auth wallet lock
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
    // TimerAuth.onOtherPage = false; // TODO:GG auth wallet unlock
    super.dispose();
  }

  _receive() {
    if (_wallet == null) return;
    WalletReceiveScreen.go(context, _wallet!);
  }

  _send() {
    if (_wallet == null) return;
    WalletSendScreen.go(context, _wallet!).then((FutureOr success) async {
      if (success != null && await success) {
        S _localizations = S.of(context);
        NotificationDialog.of(context).show(
          title: _localizations.transfer_initiated,
          content: _localizations.transfer_initiated_desc,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);

    return Layout(
      // floatingActionButton: FloatingActionButton(onPressed: () => AppScreen.go(context, index: 1)), // test
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: isDefault ? _localizations.main_wallet : (this._wallet?.name?.toUpperCase() ?? ""),
        backgroundColor: application.theme.backgroundColor4,
        actions: [
          PopupMenuButton(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            icon: Asset.iconSvg('more', width: 24),
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
            WalletAvatar(
              width: 60,
              height: 60,
              walletType: this._wallet?.type ?? WalletType.nkn,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              ethTop: 16,
              ethRight: 12,
            ),
            BlocBuilder<WalletBloc, WalletState>(
              builder: (context, state) {
                if (state is WalletLoaded) {
                  this._wallet = walletCommon.getInOriginalByAddress(state.wallets, this._wallet?.address);
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
                          _wallet != null
                              ? Label(
                                  nknFormat(_wallet?.balance ?? 0, decimalDigits: 4),
                                  maxWidth: Global.screenWidth() * 0.7,
                                  type: LabelType.h1,
                                  maxLines: 10,
                                  softWrap: true,
                                )
                              : Label('--', type: LabelType.h1),
                          Label('NKN', type: LabelType.bodySmall, color: application.theme.fontColor1), // .pad(t: 4),
                        ],
                      ),
                      _wallet?.type == WalletType.eth
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Label(nknFormat(_wallet?.balanceEth ?? 0, decimalDigits: 4), type: LabelType.bodySmall),
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
                    child: Button(
                      text: _localizations.send,
                      onPressed: _send,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
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
                          Label(
                            _localizations.wallet_name,
                            type: LabelType.h3,
                            textAlign: TextAlign.start,
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
    String? newName = await BottomDialog.of(context).showInput(
      title: _localizations.wallet_name,
      inputTip: _localizations.hint_enter_wallet_name,
      inputHint: _localizations.hint_enter_wallet_name,
      value: this._wallet?.name ?? "",
      actionText: _localizations.save,
      maxLength: 20,
    );
    if (newName == null || newName.isEmpty) return;
    setState(() {
      this._wallet?.name = newName; // update appBar title
    });
    if (this._wallet != null) {
      _walletBloc?.add(UpdateWallet(this._wallet!));
    }
  }

  _onAppBarActionSelected(int result) async {
    S _localizations = S.of(context);

    switch (result) {
      case 0: // export
        authorization.getWalletPassword(_wallet?.address, context: context).then((String? password) async {
          if (password == null || password.isEmpty) return;
          String keystore = await walletCommon.getKeystoreByAddress(_wallet?.address);

          if (_wallet?.type == WalletType.eth) {
            // TODO:GG eth export
            // final ethWallet = await Ethereum.restoreWalletSaved(
            //     schema: widget.wallet, password: password);
            //
            // Navigator.pop(this.context)
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
            if (restore.address.isEmpty || restore.address != _wallet?.address) {
              Toast.show(_localizations.password_wrong);
              return;
            }

            // TimerAuth.instance.enableAuth(); // TODO:GG wallet auth?

            if (_wallet == null) return;
            WalletExportScreen.go(
              context,
              WalletType.nkn,
              _wallet?.name ?? "",
              restore.address,
              hexEncode(restore.publicKey),
              hexEncode(restore.seed),
              restore.keystore,
            );
          }
        }).onError((error, stackTrace) {
          handleError(error, stackTrace: stackTrace);
        });
        break;
      case 1: // delete
        if (_wallet == null) return;
        ModalDialog.of(this.context).confirm(
          title: _localizations.delete_wallet_confirm_title,
          content: _localizations.delete_wallet_confirm_text,
          agree: Button(
            width: double.infinity,
            text: _localizations.delete_wallet,
            backgroundColor: application.theme.strongColor,
            onPressed: () async {
              _walletBloc?.add(DeleteWallet(this._wallet!));
              // client close
              try {
                String? clientAddress = clientCommon.address;
                if (clientAddress == null || clientAddress.isEmpty) return;
                String? walletAddress = await Wallet.pubKeyToWalletAddr(getPublicKeyByClientAddr(clientAddress));
                if (this._wallet?.address == walletAddress) {
                  await clientCommon.signOut();
                }
              } catch (e) {
                handleError(e);
              } finally {
                AppScreen.go(context);
              }
            },
          ),
          reject: Button(
            width: double.infinity,
            text: _localizations.cancel,
            fontColor: application.theme.fontColor2,
            backgroundColor: application.theme.backgroundLightColor,
            onPressed: () => Navigator.pop(this.context),
          ),
        );
        break;
    }
  }
}

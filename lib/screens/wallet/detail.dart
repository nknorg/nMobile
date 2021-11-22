import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_event.dart';
import 'package:nmobile/blocs/wallet/wallet_state.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/wallet/erc20.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/dialog/notification.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/components/wallet/avatar.dart';
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
          isDefault = state.defaultAddress == _wallet?.address;
        });
      }
    });
    walletCommon.getDefaultAddress().then((value) {
      setState(() {
        isDefault = value == _wallet?.address;
      });
    });
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
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
        NotificationDialog.of(context).show(
          title: Global.locale((s) => s.transfer_initiated, ctx: context),
          content: Global.locale((s) => s.transfer_initiated_desc, ctx: context),
        );
      }
    });
  }

  _showChangeNameDialog() async {
    String? newName = await BottomDialog.of(Global.appContext).showInput(
      title: Global.locale((s) => s.wallet_name),
      inputTip: Global.locale((s) => s.hint_enter_wallet_name),
      inputHint: Global.locale((s) => s.hint_enter_wallet_name),
      value: this._wallet?.name ?? "",
      actionText: Global.locale((s) => s.save),
      maxLength: 20,
    );
    if (this._wallet == null || newName == null || newName.isEmpty) return;
    setState(() {
      this._wallet?.name = newName; // update appBar title
    });
    if (this._wallet != null) {
      _walletBloc?.add(UpdateWallet(this._wallet!));
    }
  }

  _onAppBarActionSelected(int result) async {
    switch (result) {
      case 0: // export
        authorization.getWalletPassword(_wallet?.address).then((String? password) async {
          if (password == null || password.isEmpty) return;
          String keystore = await walletCommon.getKeystore(_wallet?.address);

          Loading.show();
          if (_wallet?.type == WalletType.eth) {
            final eth = await Ethereum.restoreByKeyStore(name: _wallet?.name ?? "", keystore: keystore, password: password);
            String ethAddress = (await eth.address).hex;
            String ethKeystore = await eth.keystore();
            Loading.dismiss();

            if (ethAddress.isEmpty || ethKeystore.isEmpty || ethAddress != _wallet?.address) {
              Toast.show(Global.locale((s) => s.password_wrong));
              return;
            }

            WalletExportScreen.go(
              context,
              WalletType.eth,
              _wallet?.name ?? "",
              ethAddress,
              eth.pubKeyHex,
              eth.privateKeyHex,
              ethKeystore,
            );
          } else {
            List<String> seedRpcList = await Global.getSeedRpcList(null, measure: true);
            Wallet nkn = await Wallet.restore(keystore, config: WalletConfig(password: password, seedRPCServerAddr: seedRpcList));
            Loading.dismiss();

            if (nkn.address.isEmpty || nkn.address != _wallet?.address) {
              Toast.show(Global.locale((s) => s.password_wrong));
              return;
            }

            WalletExportScreen.go(
              context,
              WalletType.nkn,
              _wallet?.name ?? "",
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
        break;
      case 1: // delete
        ModalDialog.of(Global.appContext).confirm(
          title: Global.locale((s) => s.delete_wallet_confirm_title),
          content: Global.locale((s) => s.delete_wallet_confirm_text),
          agree: Button(
            width: double.infinity,
            text: Global.locale((s) => s.delete_wallet),
            backgroundColor: application.theme.strongColor,
            onPressed: () async {
              if (_wallet == null || _wallet!.address.isEmpty) return;
              _walletBloc?.add(DeleteWallet(this._wallet!.address));
              // client close
              try {
                String? clientAddress = clientCommon.address;
                if (clientAddress == null || clientAddress.isEmpty) return;
                String? connectAddress;
                try {
                  String? pubKey = getPubKeyFromTopicOrChatId(clientAddress);
                  if (pubKey?.isNotEmpty == true) {
                    connectAddress = await Wallet.pubKeyToWalletAddr(pubKey!);
                  }
                } catch (e) {
                  handleError(e);
                }
                String? defaultAddress = await walletCommon.getDefaultAddress();
                if (this._wallet?.address == connectAddress || this._wallet?.address == defaultAddress) {
                  await clientCommon.signOut(closeDB: true, clearWallet: true);
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
            text: Global.locale((s) => s.cancel),
            fontColor: application.theme.fontColor2,
            backgroundColor: application.theme.backgroundLightColor,
            onPressed: () {
              if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
            },
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      // floatingActionButton: FloatingActionButton(onPressed: () => AppScreen.go(context, index: 1)), // test
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: isDefault ? Global.locale((s) => s.main_wallet, ctx: context) : (this._wallet?.name?.toUpperCase() ?? ""),
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
                child: Label(Global.locale((s) => s.export_wallet, ctx: context), type: LabelType.display),
              ),
              PopupMenuItem<int>(
                value: 1,
                child: Label(
                  Global.locale((s) => s.delete_wallet, ctx: context),
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
                  // refresh balance
                  List<WalletSchema> finds = state.wallets.where((w) => w.address == this._wallet?.address).toList();
                  if (finds.isNotEmpty) {
                    this._wallet = finds[0];
                  }
                  // else {
                  //   if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
                  // }
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
                      text: Global.locale((s) => s.send, ctx: context),
                      onPressed: _send,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Button(
                      text: Global.locale((s) => s.receive, ctx: context),
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
                            Global.locale((s) => s.wallet_name, ctx: context),
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
                      copyText(this._wallet?.address);
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
                                Global.locale((s) => s.wallet_address, ctx: context),
                                type: LabelType.h3,
                                textAlign: TextAlign.start,
                              ),
                              Label(
                                Global.locale((s) => s.copy, ctx: context),
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
}

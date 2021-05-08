import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/form_field_box.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/wallet/avatar.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/assets.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/utils.dart';

class WalletDetailNKNScreen extends StatefulWidget {
  static const String routeName = '/wallet/detail_nkn';
  static final String argWallet = "wallet";
  static final String argListIndex = "list_index";

  final Map<String, dynamic> arguments;

  const WalletDetailNKNScreen({Key key, this.arguments}) : super(key: key);

  @override
  _WalletDetailNKNScreenState createState() => _WalletDetailNKNScreenState();
}

class _WalletDetailNKNScreenState extends State<WalletDetailNKNScreen> {
  WalletSchema _wallet;
  int _listIndex;

  WalletBloc _walletBloc;

  // NKNClientBloc _clientBloc;
  // bool isDefault = false;
  TextEditingController _nameController = TextEditingController();

  // WalletSchema _currWallet;

  @override
  void initState() {
    super.initState();
    this._wallet = widget.arguments[WalletDetailNKNScreen.argWallet];
    this._listIndex = widget.arguments[WalletDetailNKNScreen.argListIndex];

    // TODO:GG
    _walletBloc = BlocProvider.of<WalletBloc>(context);
    // _clientBloc = BlocProvider.of<NKNClientBloc>(context);
    _nameController.text = this._wallet?.name ?? "";
    // widget.wallet.isDefaultWallet().then((v) {
    //   if (mounted) {
    //     setState(() {
    //       isDefault = v;
    //     });
    //   }
    // });
    //
    // TimerAuth.onOtherPage = true;
  }

  @override
  void dispose() {
    super.dispose();
    // TimerAuth.onOtherPage = false;
  }

  _receive() {
    // TODO:GG receive
    // Navigator.of(context).pushNamed(ReceiveNknScreen.routeName, arguments: widget.wallet);
  }

  _send() {
    // TODO:GG send
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
        title: this._listIndex == 0 ? _localizations.main_wallet : this._wallet?.name?.toUpperCase(), // TODO:GG wait best
        backgroundColor: application.theme.backgroundColor4,
        actions: [
          PopupMenuButton(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            icon: assetIcon('more', width: 24),
            onSelected: (int result) {
              _onMenuSelected(result);
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
      child: SingleChildScrollView(
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
                          _wallet != null ? Label(nknFormat(_wallet?.balance, decimalDigits: 4), type: LabelType.h1) : Label('--', type: LabelType.h1),
                          Label('NKN', type: LabelType.bodySmall, color: application.theme.fontColor1), // .pad(t: 4),
                        ],
                      ),
                      _wallet != null && _wallet.type == WalletType.eth
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Label(nknFormat(_wallet.balanceEth, decimalDigits: 4), type: LabelType.bodySmall),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Label(
                            _localizations.wallet_name,
                            type: LabelType.h3,
                            textAlign: TextAlign.start,
                          ),
                        ],
                      ),
                      FormFieldBox(
                        controller: _nameController,
                        readOnly: true,
                      ),
                    ],
                  ),
                ),
                Material(
                  elevation: 0,
                  child: InkWell(
                    onTap: () {
                      copyText(this._wallet?.address, context: context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
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
                          FormFieldBox(
                            value: this._wallet?.address,
                            readOnly: true,
                            enabled: false,
                          ),
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

  // TextEditingController _walletNameController = TextEditingController();
  // GlobalKey _nameFormKey = new GlobalKey<FormState>();

  showChangeNameDialog() {
    // BottomDialog.of(context).showBottomDialog(
    //   title: _localizations.wallet_name,
    //   child: Form(
    //     autovalidate: false,
    //     key: _nameFormKey,
    //     onChanged: () {},
    //     child: Flex(
    //       direction: Axis.horizontal,
    //       children: <Widget>[
    //         Expanded(
    //           flex: 1,
    //           child: Padding(
    //             padding: const EdgeInsets.only(right: 4),
    //             child: Column(
    //               crossAxisAlignment: CrossAxisAlignment.start,
    //               children: <Widget>[
    //                 Textbox(
    //                   controller: _walletNameController,
    //                   hintText: _localizations.hint_enter_wallet_name,
    //                   maxLength: 20,
    //                 ),
    //               ],
    //             ),
    //           ),
    //         ),
    //       ],
    //     ),
    //   ),
    //   action: Padding(
    //     padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 34),
    //     child: Button(
    //       text: _localizations.save,
    //       width: double.infinity,
    //       onPressed: () async {
    //         if (_walletNameController.text != null && _walletNameController.text.length > 0) {
    //           setState(() {
    //             widget.wallet.name = _walletNameController.text;
    //             _nameController.text = _walletNameController.text;
    //           });
    //           _walletsBloc.add(UpdateWallet(widget.wallet));
    //         }
    //         Navigator.of(context).pop();
    //       },
    //     ),
    //   ),
    // );
  }

  _onMenuSelected(int result) async {
    // switch (result) {
    //   case 0:
    //     if (widget.wallet.type == WalletSchema.ETH_WALLET) {
    //       var password = await widget.wallet.getPassword();
    //       if (password != null) {
    //         try {
    //           final ethWallet = await Ethereum.restoreWalletSaved(schema: widget.wallet, password: password);
    //
    //           Navigator.of(context).pushNamed(NknWalletExportScreen.routeName, arguments: {
    //             'wallet': null,
    //             'keystore': ethWallet.keystore,
    //             'address': (await ethWallet.address).hex,
    //             'publicKey': ethWallet.pubkeyHex,
    //             'seed': ethWallet.privateKeyHex,
    //             'name': ethWallet.name,
    //           });
    //         } catch (e) {
    //           showToast(_localizations.password_wrong);
    //         }
    //       }
    //     } else {
    //       var password = await widget.wallet.getPassword();
    //       if (password != null) {
    //         try {
    //           var wallet = await widget.wallet.exportWallet(password);
    //           if (wallet['address'] == widget.wallet.address) {
    //             TimerAuth.instance.enableAuth();
    //
    //             Navigator.of(context).pushNamed(NknWalletExportScreen.routeName, arguments: {
    //               'wallet': wallet,
    //               'keystore': wallet['keystore'],
    //               'address': wallet['address'],
    //               'publicKey': wallet['publicKey'],
    //               'seed': wallet['seed'],
    //               'name': isDefault ? _localizations.main_wallet : widget.wallet.name,
    //             });
    //           } else {
    //             showToast(_localizations.password_wrong);
    //           }
    //         } catch (e) {
    //           if (e.message == ConstUtils.WALLET_PASSWORD_ERROR) {
    //             showToast(_localizations.password_wrong);
    //           }
    //         }
    //       }
    //     }
    //     break;
    //   case 1:
    //     SimpleConfirm(
    //             context: context,
    //             title: _localizations.delete_wallet_confirm_title,
    //             content: _localizations.delete_wallet_confirm_text,
    //             callback: (v) async {
    //               if (v) {
    //                 _walletsBloc.add(DeleteWallet(widget.wallet));
    //                 if (NKNClientCaller.currentChatId != null) {
    //                   var walletAddr = await NknWalletPlugin.pubKeyToWalletAddr(NKNClientCaller.currentChatId);
    //                   if (walletAddr == widget.wallet.address) {
    //                     NLog.d('delete client');
    //                     _clientBloc.add(NKNDisConnectClientEvent());
    //                   } else {
    //                     NLog.d('no delete client');
    //                   }
    //                 }
    //                 Navigator.popAndPushNamed(context, AppScreen.routeName);
    //               }
    //             },
    //             buttonColor: Colors.red,
    //             buttonText: _localizations.delete_wallet)
    //         .show();
    //     break;
    // }
  }
}

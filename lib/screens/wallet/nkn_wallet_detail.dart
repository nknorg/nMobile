import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/blocs/account_depends_bloc.dart';
import 'package:nmobile/blocs/client/client_bloc.dart';
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_event.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/notification.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/eth_erc20_token.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/view/dialog_confirm.dart';
import 'package:nmobile/screens/wallet/nkn_wallet_export.dart';
import 'package:nmobile/screens/wallet/recieve_nkn.dart';
import 'package:nmobile/screens/wallet/send_erc_20.dart';
import 'package:nmobile/screens/wallet/send_nkn.dart';
import 'package:nmobile/utils/const_utils.dart';
import 'package:nmobile/utils/copy_utils.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:oktoast/oktoast.dart';

class NknWalletDetailScreen extends StatefulWidget {
  static const String routeName = '/wallet/nkn_wallet_detail';
  final WalletSchema arguments;

  NknWalletDetailScreen({this.arguments});

  @override
  _NknWalletDetailScreenState createState() => _NknWalletDetailScreenState();
}

class _NknWalletDetailScreenState extends State<NknWalletDetailScreen> with AccountDependsBloc {
  WalletsBloc _walletsBloc;
  ClientBloc _clientBloc;
  bool isDefault = false;
  TextEditingController _nameController = TextEditingController();
  WalletSchema _currWallet;

  @override
  void initState() {
    super.initState();
    _walletsBloc = BlocProvider.of<WalletsBloc>(context);
    _clientBloc = BlocProvider.of<ClientBloc>(context);
    _nameController.text = widget.arguments.name;
    widget.arguments.isDefaultWallet().then((v) {
      if (mounted) {
        setState(() {
          isDefault = v;
        });
      }
    });
  }

  _receive() {
    Navigator.of(context).pushNamed(ReceiveNknScreen.routeName, arguments: widget.arguments);
  }

  _send() {
    Navigator.of(context)
        .pushNamed(
      widget.arguments.type == WalletSchema.ETH_WALLET ? SendErc20Screen.routeName : SendNknScreen.routeName,
      arguments: widget.arguments,
    )
        .then((FutureOr success) async {
      if (success != null && await success) {
        NotificationDialog.of(context).show(
          title: NMobileLocalizations.of(context).transfer_initiated,
          content: NMobileLocalizations.of(context).transfer_initiated_desc,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        title: widget.arguments.type == WalletSchema.ETH_WALLET ? NMobileLocalizations.of(context).eth_wallet : NMobileLocalizations.of(context).main_wallet,
        backgroundColor: DefaultTheme.backgroundColor4,
        action: PopupMenuButton(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          icon: loadAssetIconsImage('more', width: 24),
          onSelected: _onMenuSelected,
          itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
            PopupMenuItem<int>(
              value: 0,
              child: Label(NMobileLocalizations.of(context).export_wallet, type: LabelType.display),
            ),
            PopupMenuItem<int>(
              value: 1,
              child: Label(
                NMobileLocalizations.of(context).delete_wallet,
                type: LabelType.display,
                color: DefaultTheme.strongColor,
              ),
            ),
          ],
        ),
      ),
      body: Builder(
        builder: (BuildContext context) => BodyBox(
          padding: const EdgeInsets.only(top: 0, left: 20, right: 20),
          color: DefaultTheme.backgroundLightColor,
          child: SingleChildScrollView(
            child: Flex(
              direction: Axis.vertical,
              children: <Widget>[
                Expanded(
                  flex: 0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: <Widget>[
                        Hero(
                          tag: 'avatar:${widget.arguments.address}',
                          child: Stack(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colours.light_ff,
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                                child: SvgPicture.asset('assets/logo.svg', color: Colours.purple_2e),
                              ).symm(h: 16, v: 20),
                              widget.arguments.type == WalletSchema.NKN_WALLET
                                  ? Space.empty
                                  : Positioned(
                                      top: 16,
                                      left: 60,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(color: Colours.purple_53, shape: BoxShape.circle),
                                        child: SvgPicture.asset('assets/ethereum-logo.svg'),
                                      ),
                                    )
                            ],
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 0,
                              child: BlocBuilder<WalletsBloc, WalletsState>(builder: (context, state) {
                                if (state is WalletsLoaded) {
                                  _currWallet = state.wallets.firstWhere((x) => x.address == widget.arguments.address, orElse: () => null);
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _currWallet != null
                                            ? Label(Format.nknFormat(_currWallet.balance, decimalDigits: 4), type: LabelType.h1)
                                            : Label('--', type: LabelType.h1),
                                        Label('NKN', type: LabelType.bodySmall, color: DefaultTheme.fontColor1).pad(t: 4),
                                      ],
                                    ),
                                    _currWallet != null && _currWallet.type == WalletSchema.ETH_WALLET
                                        ? Row(
                                            children: [
                                              Label(Format.nknFormat(_currWallet.balanceEth, decimalDigits: 4), type: LabelType.bodySmall),
                                              Label('ETH', type: LabelType.bodySmall, color: DefaultTheme.fontColor1).pad(l: 6, r: 2),
                                            ],
                                          )
                                        : Space.empty,
                                  ],
                                );
                              }).pad(t: 16, b: 8, l: 34),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 24, bottom: 40),
                          child: Flex(
                            direction: Axis.horizontal,
                            children: <Widget>[
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Button(
                                    text: NMobileLocalizations.of(context).send,
                                    onPressed: _send,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Button(
                                    text: NMobileLocalizations.of(context).receive,
                                    onPressed: _receive,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Label(
                                    NMobileLocalizations.of(context).wallet_name,
                                    type: LabelType.h3,
                                    textAlign: TextAlign.start,
                                  ),
//                                  InkWell(
//                                    child: Label(
//                                      NMobileLocalizations.of(context).rename,
//                                      color: DefaultTheme.primaryColor,
//                                      type: LabelType.bodyLarge,
//                                    ),
//                                    onTap: () {
//                                      showChangeNameDialog();
//                                    },
//                                  ),
                                ],
                              ),
                              Textbox(
                                controller: _nameController,
                                readOnly: true,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Label(
                                    NMobileLocalizations.of(context).wallet_address,
                                    type: LabelType.h3,
                                    textAlign: TextAlign.start,
                                  ),
                                  InkWell(
                                    child: Label(
                                      NMobileLocalizations.of(context).copy,
                                      color: DefaultTheme.primaryColor,
                                      type: LabelType.bodyLarge,
                                    ),
                                    onTap: () {
                                      CopyUtils.copyAction(context, widget.arguments.address);
                                    },
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () {
                                  CopyUtils.copyAction(context, widget.arguments.address);
                                },
                                child: Textbox(
                                  value: widget.arguments.address,
                                  readOnly: true,
                                  enabled: false,
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextEditingController _walletNameController = TextEditingController();
  GlobalKey _nameFormKey = new GlobalKey<FormState>();

  showChangeNameDialog() {
    BottomDialog.of(context).showBottomDialog(
      title: NMobileLocalizations.of(context).wallet_name,
      child: Form(
        autovalidate: false,
        key: _nameFormKey,
        onChanged: () {},
        child: Flex(
          direction: Axis.horizontal,
          children: <Widget>[
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Textbox(
                      controller: _walletNameController,
                      hintText: NMobileLocalizations.of(context).hint_enter_wallet_name,
                      maxLength: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      action: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 34),
        child: Button(
          text: NMobileLocalizations.of(context).save,
          width: double.infinity,
          onPressed: () async {
            if (_walletNameController.text != null && _walletNameController.text.length > 0) {
              setState(() {
                widget.arguments.name = _walletNameController.text;
                _nameController.text = _walletNameController.text;
              });
              _walletsBloc.add(UpdateWallet(widget.arguments));
            }
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  _onMenuSelected(int result) async {
    switch (result) {
      case 0:
        if (widget.arguments.type == WalletSchema.ETH_WALLET) {
          var password = await widget.arguments.getPassword();
          if (password != null) {
            try {
              final ethWallet = await Ethereum.restoreWalletSaved(schema: widget.arguments, password: password);
              Navigator.of(context).pushNamed(NknWalletExportScreen.routeName, arguments: {
                'wallet': null,
                'keystore': ethWallet.keystore,
                'address': (await ethWallet.address).hex,
                'publicKey': ethWallet.pubkeyHex,
                'seed': ethWallet.privateKeyHex,
                'name': ethWallet.name,
              });
            } catch (e) {
              showToast(NMobileLocalizations.of(context).password_wrong);
            }
          }
        } else {
          var password = await widget.arguments.getPassword();
          if (password != null) {
            try {
              var wallet = await widget.arguments.exportWallet(password);
              if (wallet['address'] == widget.arguments.address) {
                Navigator.of(context).pushNamed(NknWalletExportScreen.routeName, arguments: {
                  'wallet': wallet,
                  'keystore': wallet['keystore'],
                  'address': wallet['address'],
                  'publicKey': wallet['publicKey'],
                  'seed': wallet['seed'],
                  'name': isDefault ? NMobileLocalizations.of(context).main_wallet : widget.arguments.name,
                });
              } else {
                showToast(NMobileLocalizations.of(context).password_wrong);
              }
            } catch (e) {
              if (e.message == ConstUtils.WALLET_PASSWORD_ERROR) {
                showToast(NMobileLocalizations.of(context).password_wrong);
              }
            }
          }
        }
        break;
      case 1:
        SimpleConfirm(
                context: context,
                title: NMobileLocalizations.of(context).delete_wallet_confirm_title,
                content: NMobileLocalizations.of(context).delete_wallet_confirm_text,
                callback: (v) async {
                  if (v) {
                    _walletsBloc.add(DeleteWallet(widget.arguments));
                    if (account?.client?.pubkey != null) {
                      var walletAddr = await NknWalletPlugin.pubKeyToWalletAddr(accountPubkey);
                      if (walletAddr == widget.arguments.address) {
                        NLog.d('delete client');
                        _clientBloc.add(DisConnected());
                      } else {
                        NLog.d('no delete client');
                      }
                    }
                    Navigator.popAndPushNamed(context, AppScreen.routeName);
                  }
                },
                buttonColor: Colors.red,
                buttonText: NMobileLocalizations.of(context).delete_wallet)
            .show();
//                ModalDialog.of(context).show(
//                  height: 450,
//                  title: Label(
//                    NMobileLocalizations.of(context).delete_wallet_confirm_title,
//                    type: LabelType.h2,
//                    softWrap: true,
//                  ),
//                  content: Column(
//                    children: <Widget>[
//                      WalletItem(
//                        schema: widget.arguments,
//                        onTap: () {},
//                      ),
//                      Label(
//                        NMobileLocalizations.of(context).delete_wallet_confirm_text,
//                        type: LabelType.bodyRegular,
//                        softWrap: true,
//                      ),
//                    ],
//                  ),
//                  actions: <Widget>[
//                    Button(
//                      child: Row(
//                        mainAxisAlignment: MainAxisAlignment.center,
//                        children: <Widget>[
//                          Padding(
//                            padding: const EdgeInsets.only(right: 8),
//                            child: loadAssetIconsImage(
//                              'trash',
//                              color: DefaultTheme.backgroundLightColor,
//                              width: 24,
//                            ),
//                          ),
//                          Label(
//                            NMobileLocalizations.of(context).delete_wallet,
//                            type: LabelType.h3,
//                          )
//                        ],
//                      ),
//                      backgroundColor: DefaultTheme.strongColor,
//                      width: double.infinity,
//                      onPressed: () async {
//                        _walletsBloc.add(DeleteWallet(widget.arguments));
//                        if (Global?.currentClient?.address != null) {
//                          var s = await NknWalletPlugin.pubKeyToWalletAddr(getPublicKeyByClientAddr(Global.currentClient?.publicKey));
//                          if (s.toString() == widget.arguments.address) {
//                            NLog.d('delete client ');
//                            _clientBloc.add(DisConnected());
//                          } else {
//                            NLog.d('no delete client ');
//                          }
//                        }
//                        Navigator.popAndPushNamed(context, AppScreen.routeName);
//                      },
//                    ),
//                  ],
//                );
        break;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/blocs/client/client_bloc.dart';
import 'package:nmobile/blocs/client/client_event.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_event.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/dialog/notification.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/components/wallet/item.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/wallet/nkn_wallet_export.dart';
import 'package:nmobile/screens/wallet/recieve_nkn.dart';
import 'package:nmobile/screens/wallet/send_nkn.dart';
import 'package:nmobile/utils/const_utils.dart';
import 'package:nmobile/utils/copy_utils.dart';
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

class _NknWalletDetailScreenState extends State<NknWalletDetailScreen> {
  WalletsBloc _walletsBloc;
  ClientBloc _clientBloc;
  TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _walletsBloc = BlocProvider.of<WalletsBloc>(context);
    _clientBloc = BlocProvider.of<ClientBloc>(context);
    _nameController.text = widget.arguments.name;
  }

  _receive() {
    Navigator.of(context).pushNamed(ReceiveNknScreen.routeName, arguments: widget.arguments);
  }

  _send() {
    Navigator.of(context).pushNamed(SendNknScreen.routeName, arguments: widget.arguments).then((v) {
      if (v != null) {
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
        title: NMobileLocalizations.of(context).main_wallet.toUpperCase(),
        backgroundColor: DefaultTheme.backgroundColor4,
        action: PopupMenuButton(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          icon: loadAssetIconsImage(
            'more',
            width: 24,
          ),
          onSelected: (int result) async {
            switch (result) {
              case 0:
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
                break;
              case 1:
                ModalDialog.of(context).show(
                  height: 450,
                  title: Label(
                    NMobileLocalizations.of(context).delete_wallet_confirm_title,
                    type: LabelType.h2,
                    softWrap: true,
                  ),
                  content: Column(
                    children: <Widget>[
                      WalletItem(
                        schema: widget.arguments,
                        onTap: () {},
                      ),
                      Label(
                        NMobileLocalizations.of(context).delete_wallet_confirm_text,
                        type: LabelType.bodyRegular,
                        softWrap: true,
                      ),
                    ],
                  ),
                  actions: <Widget>[
                    Button(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: loadAssetIconsImage(
                              'trash',
                              color: DefaultTheme.backgroundLightColor,
                              width: 24,
                            ),
                          ),
                          Label(
                            NMobileLocalizations.of(context).delete_wallet,
                            type: LabelType.h3,
                          )
                        ],
                      ),
                      backgroundColor: DefaultTheme.strongColor,
                      width: double.infinity,
                      onPressed: () async {
                        _walletsBloc.add(DeleteWallet(widget.arguments));
                        if (Global?.currentClient?.address != null) {
                          var s = await NknWalletPlugin.pubKeyToWalletAddr(getPublicKeyByClientAddr(Global.currentClient?.publicKey));
                          if (s.toString() == widget.arguments.address) {
                            NLog.d('delete client ');
                            _clientBloc.add(DisConnected());
                          } else {
                            NLog.d('no delete client ');
                          }
                        }
                        Navigator.popAndPushNamed(context, AppScreen.routeName);
                      },
                    ),
                  ],
                );
                break;
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
            PopupMenuItem<int>(
              value: 0,
              child: Label(
                NMobileLocalizations.of(context).export_wallet,
                type: LabelType.display,
              ),
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
                    padding: const EdgeInsets.only(top: 32),
                    child: Column(
                      children: <Widget>[
                        Hero(
                          tag: 'avatar:${widget.arguments.address}',
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Color(0xFFF1F4FF),
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            child: SvgPicture.asset('assets/logo.svg', color: Color(0xFF253A7E)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8, left: 34),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              BlocBuilder<WalletsBloc, WalletsState>(
                                builder: (context, state) {
                                  if (state is WalletsLoaded) {
                                    var w = state.wallets.firstWhere((x) => x == widget.arguments, orElse: () => null);
                                    if (w != null) {
                                      return Label(
                                        Format.nknFormat(w.balance, decimalDigits: 4),
                                        type: LabelType.h1,
                                      );
                                    }
                                  }
                                  return Label(
                                    '',
                                    type: LabelType.h1,
                                  );
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 4),
                                child: Label(
                                  'NKN',
                                  type: LabelType.bodySmall,
                                  color: DefaultTheme.fontColor1,
                                ),
                              ),
                            ],
                          ),
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
                                    text: NMobileLocalizations.of(context).recieve,
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
                                  InkWell(
                                    child: Label(
                                      NMobileLocalizations.of(context).rename,
                                      color: DefaultTheme.primaryColor,
                                      type: LabelType.bodyLarge,
                                    ),
                                    onTap: () {
                                      showChangeNameDialog();
                                    },
                                  ),
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
}

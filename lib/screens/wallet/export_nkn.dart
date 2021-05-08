import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:nmobile/utils/assets.dart';
import 'package:nmobile/utils/utils.dart';

class WalletExportNKNScreen extends StatefulWidget {
  static const String routeName = '/wallet/export_nkn';
  static final String argName = "name";
  static final String argWalletType = "wallet_type";
  static final String argAddress = "address";
  static final String argPublicKey = "public_key";
  static final String argSeed = "seed";
  static final String argKeystore = "keystore";

  final Map<String, dynamic> arguments;

  WalletExportNKNScreen({Key key, this.arguments}) : super(key: key);

  @override
  _WalletExportNKNScreenState createState() => _WalletExportNKNScreenState();
}

class _WalletExportNKNScreenState extends State<WalletExportNKNScreen> {
  String _name;
  String _walletType;
  String _address;
  String _publicKey;
  String _seed;
  String _keystore;
  WalletBloc _walletBloc;

  _setBackupFlag() {
    // _walletsBloc.add(UpdateWalletBackedUp(address));
  }

  @override
  void initState() {
    super.initState();
    _name = widget.arguments[WalletExportNKNScreen.argName];
    _walletType = widget.arguments[WalletExportNKNScreen.argWalletType];
    _address = widget.arguments[WalletExportNKNScreen.argAddress];
    _publicKey = widget.arguments[WalletExportNKNScreen.argPublicKey];
    _seed = widget.arguments[WalletExportNKNScreen.argSeed];
    _keystore = widget.arguments[WalletExportNKNScreen.argKeystore];

    _walletBloc = BlocProvider.of<WalletBloc>(context);
  }

  _getItemWidgets(String icon, String title, String value) {
    if (value == null || value.isEmpty) return SizedBox.shrink();
    return InkWell(
      onTap: () {
        copyText(value, context: context);
      },
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 0,
            child: Padding(
              padding: const EdgeInsets.only(left: 0, right: 20),
              child: assetImage(
                icon,
                width: 24,
                color: application.theme.primaryColor,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Label(
                      title,
                      type: LabelType.h4,
                      textAlign: TextAlign.start,
                    ),
                    Label(
                      "_localizations.copy",
                      color: application.theme.primaryColor,
                      type: LabelType.bodyRegular,
                    ),
                  ],
                ),
                FormFieldBox(
                  multi: true,
                  enabled: false,
                  value: value,
                  readOnly: true,
                  textInputAction: TextInputAction.next,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);

    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: _localizations.export_wallet,
        backgroundColor: application.theme.backgroundColor4,
      ),
      child: Column(
        children: <Widget>[
          Expanded(
            flex: 1,
            child: Padding(
              padding: EdgeInsets.only(top: 0),
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
                              tag: 'avatar:$_address',
                              child: WalletAvatar(
                                width: 48,
                                height: 48,
                                walletType: this._walletType,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 16, bottom: 40),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Label(
                                    _name ?? '',
                                    type: LabelType.h2,
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 0,
                              child: Column(
                                children: <Widget>[
                                  _getItemWidgets('wallet', _localizations.wallet_address, _address),
                                  _getItemWidgets('key', "_localizations.public_key", _publicKey),
                                  _getItemWidgets('key', _localizations.seed, _seed),
                                  _getItemWidgets('key', _localizations.keystore, _keystore),
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
          _seed == null || _seed.isEmpty
              ? SizedBox.shrink()
              : Expanded(
                  flex: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 8, top: 8),
                      child: Column(
                        children: <Widget>[
                          Button(
                            child: Label(
                              "_localizations.view_qrcode",
                              type: LabelType.h3,
                              color: application.theme.primaryColor,
                            ),
                            backgroundColor: application.theme.primaryColor.withAlpha(20),
                            fontColor: application.theme.primaryColor,
                            onPressed: () {
                              // TODO:GG qr
                              // BottomDialog.of(context).showQrcodeDialog(
                              //   title: _localizations.seed + _localizations.qrcode,
                              //   data: seed,
                              // );
                              // _setBackupFlag();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

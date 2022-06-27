import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_event.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/wallet/avatar.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/util.dart';

class WalletExportScreen extends BaseStateFulWidget {
  static const String routeName = '/wallet/export_nkn';
  static final String argWalletType = "wallet_type";
  static final String argName = "name";
  static final String argAddress = "address";
  static final String argPublicKey = "public_key";
  static final String argSeed = "seed";
  static final String argKeystore = "keystore";

  static Future go(
    BuildContext context,
    String? walletType,
    String? name,
    String address,
    String publicKey,
    String seed,
    String keystore,
  ) {
    logger.d("WalletExportScreen - go - type:$walletType  name:$name \n address:$address \n publicKey:$publicKey \n seed:$seed \n keystore:$keystore");
    return Navigator.pushNamed(context, routeName, arguments: {
      argWalletType: walletType ?? WalletType.nkn,
      argName: name ?? "",
      argAddress: address,
      argPublicKey: publicKey,
      argSeed: seed,
      argKeystore: keystore,
    });
  }

  final Map<String, dynamic>? arguments;

  WalletExportScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _WalletExportScreenState createState() => _WalletExportScreenState();
}

class _WalletExportScreenState extends BaseStateFulWidgetState<WalletExportScreen> {
  String? _walletType;
  String? _name;
  String? _address;
  String? _publicKey;
  String? _seed;
  String? _keystore;
  WalletBloc? _walletBloc;

  @override
  void onRefreshArguments() {
    _name = widget.arguments![WalletExportScreen.argName];
    _walletType = widget.arguments![WalletExportScreen.argWalletType];
    _address = widget.arguments![WalletExportScreen.argAddress];
    _publicKey = widget.arguments![WalletExportScreen.argPublicKey];
    _seed = widget.arguments![WalletExportScreen.argSeed];
    _keystore = widget.arguments![WalletExportScreen.argKeystore];
  }

  @override
  void initState() {
    super.initState();
    _walletBloc = BlocProvider.of<WalletBloc>(context);
  }

  _setBackupFlag() {
    if (_address != null) {
      _walletBloc?.add(BackupWallet(_address!, true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.backgroundColor4,
      header: Header(
        title: Global.locale((s) => s.export_wallet, ctx: context),
        backgroundColor: application.theme.backgroundColor4,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 0),
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Column(
                        children: <Widget>[
                          WalletAvatar(
                            width: 48,
                            height: 48,
                            walletType: this._walletType ?? WalletType.nkn,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 40),
                            child: Label(
                              _name ?? '',
                              type: LabelType.h2,
                            ),
                          ),
                          Column(
                            children: <Widget>[
                              _getItemWidgets('wallet', Global.locale((s) => s.wallet_address, ctx: context), _address),
                              _getItemWidgets('key', Global.locale((s) => s.public_key, ctx: context), _publicKey),
                              _getItemWidgets('key', Global.locale((s) => s.seed, ctx: context), _seed, backupOk: true),
                              _getItemWidgets('key', Global.locale((s) => s.keystore, ctx: context), _keystore, backupOk: true),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _seed == null || _seed!.isEmpty
              ? SizedBox.shrink()
              : SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 30),
                          child: Button(
                            child: Label(
                              Global.locale((s) => s.view_qrcode, ctx: context),
                              type: LabelType.h3,
                              color: application.theme.primaryColor,
                            ),
                            backgroundColor: application.theme.primaryColor.withAlpha(20),
                            fontColor: application.theme.primaryColor,
                            width: double.infinity,
                            onPressed: () {
                              BottomDialog.of(Global.appContext).showQrcode(
                                title: Global.locale((s) => s.seed) + Global.locale((s) => s.qrcode),
                                desc: Global.locale((s) => s.seed_qrcode_dec),
                                data: _seed!,
                              );
                              _setBackupFlag();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  _getItemWidgets(String icon, String title, String? value, {bool backupOk = false}) {
    if (value == null || value.isEmpty) return SizedBox.shrink();

    return Material(
      color: application.theme.backgroundColor1,
      elevation: 0,
      child: InkWell(
        onTap: () {
          Util.copyText(value);
          if (backupOk) {
            _setBackupFlag();
          }
        },
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Asset.iconSvg(
                icon,
                width: 24,
                color: application.theme.primaryColor,
              ),
              SizedBox(width: 20),
              Expanded(
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
                          Global.locale((s) => s.copy, ctx: context),
                          color: application.theme.primaryColor,
                          type: LabelType.bodyRegular,
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    Label(
                      value,
                      type: LabelType.display,
                      maxLines: 10,
                    ),
                    SizedBox(height: 15),
                    Divider(height: 1),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

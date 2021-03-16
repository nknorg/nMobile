import 'package:flutter/material.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/tabs.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/event/eventbus.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/scanner.dart';
import 'package:nmobile/screens/wallet/import_keystore_nkn_eth_wallet.dart';
import 'package:nmobile/screens/wallet/import_seed_nkn_eth_wallet.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:nmobile/utils/nlog_util.dart';

class ImportWalletScreen extends StatefulWidget {
  static const String routeName = '/wallet/import_nkn_wallet';

  final WalletType type;

  const ImportWalletScreen({this.type});

  @override
  _ImportWalletScreenState createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen>
    with SingleTickerProviderStateMixin {
  TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    List<String> tabs = [
      NL10ns.of(context).tab_keystore,
      NL10ns.of(context).tab_seed
    ];
    return Scaffold(
      appBar: Header(
        title: widget.type == WalletType.eth
            ? NL10ns.of(context).import_ethereum_wallet
            : NL10ns.of(context).import_nkn_wallet,
        backgroundColor: DefaultTheme.backgroundColor4,
        action: IconButton(
          icon: loadAssetIconsImage(
            'scan',
            width: 24,
            color: DefaultTheme.backgroundLightColor,
          ),
          onPressed: () async {
            var qrData =
                await Navigator.of(context).pushNamed(ScannerScreen.routeName);
            eventBus.fire(QMScan(qrData));
            NLog.d(qrData);
          },
        ),
      ),
      body: ConstrainedBox(
        constraints: BoxConstraints.expand(),
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).requestFocus(FocusNode());
          },
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height),
                child: Container(
                  constraints: BoxConstraints.expand(),
                  color: DefaultTheme.backgroundColor4,
                  child: Flex(
                    direction: Axis.vertical,
                    children: <Widget>[
                      Expanded(
                        flex: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: DefaultTheme.backgroundLightColor,
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(32)),
                          ),
                          child: Flex(
                            direction: Axis.vertical,
                            children: <Widget>[
                              Expanded(
                                flex: 0,
                                child: Tabs(
                                  controller: _tabController,
                                  tabs: tabs,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Padding(
                                  padding: EdgeInsets.only(top: 0.2),
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: <Widget>[
                                      ImportKeystoreWallet(type: widget.type),
                                      ImportSeedWallet(type: widget.type),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
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
    );
  }
}

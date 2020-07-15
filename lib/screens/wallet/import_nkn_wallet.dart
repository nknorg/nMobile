import 'package:flutter/material.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/tabs.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/event/eventbus.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/screens/scanner.dart';
import 'package:nmobile/screens/wallet/import_keystore_nkn_wallet.dart';
import 'package:nmobile/screens/wallet/import_seed_nkn_wallet.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:nmobile/utils/nlog_util.dart';

class ImportNknWalletScreen extends StatefulWidget {
  static const String routeName = '/wallet/import_nkn_wallet';

  @override
  _ImportNknWalletScreenState createState() => _ImportNknWalletScreenState();
}

class _ImportNknWalletScreenState extends State<ImportNknWalletScreen> with SingleTickerProviderStateMixin {
  TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    List<String> tabs = [NMobileLocalizations.of(context).tab_keystore, NMobileLocalizations.of(context).tab_seed];
    return Scaffold(
      appBar: Header(
        title: NMobileLocalizations.of(context).create_nkn_wallet_title,
        backgroundColor: DefaultTheme.backgroundColor4,
        action: IconButton(
          icon: loadAssetIconsImage(
            'scan',
            width: 24,
            color: DefaultTheme.backgroundLightColor,
          ),
          onPressed: () async {
            var qrData = await Navigator.of(context).pushNamed(ScannerScreen.routeName);
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
                constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
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
                            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                                      ImportKeystoreNknWallet(),
                                      ImportSeedNknWallet(),
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

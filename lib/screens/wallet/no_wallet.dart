import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/screens/wallet/create_nkn_wallet.dart';
import 'package:nmobile/screens/wallet/import_nkn_wallet.dart';

class NoWalletScreen extends StatefulWidget {
  static const String routeName = '/no_wallet';

  @override
  _NoWalletScreenState createState() => _NoWalletScreenState();
}

class _NoWalletScreenState extends State<NoWalletScreen> {
  final GetIt locator = GetIt.instance;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints.expand(),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            color: DefaultTheme.backgroundColor4,
            constraints: BoxConstraints.expand(),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: Container(
                  height: MediaQuery.of(context).size.height - 120,
                  child: Flex(
                    direction: Axis.vertical,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        flex: 0,
                        child: Padding(
                          padding: EdgeInsets.only(),
                          child: Image(
                            image: AssetImage('assets/wallet/pig.png'),
                            width: 120,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 0,
                        child: Column(
                          children: <Widget>[
                            Padding(
                              padding: EdgeInsets.only(top: 32),
                              child: Label(
                                NMobileLocalizations.of(context).no_wallet_title,
                                type: LabelType.h2,
                                dark: true,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(top: 8, left: 38, right: 38),
                              child: Label(
                                NMobileLocalizations.of(context).no_wallet_desc,
                                type: LabelType.h4,
                                dark: true,
                                textAlign: TextAlign.center,
                              ),
                            )
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 0,
                        child: Column(
                          children: <Widget>[
                            Padding(
                              padding: EdgeInsets.only(top: 100, left: 30, right: 30),
                              child: Button(
                                text: NMobileLocalizations.of(context).no_wallet_create,
                                onPressed: () {
//                                  locator<NavigateService>().pushNamed(CreateNknWalletScreen.routeName);
                                  Navigator.pushNamed(context, CreateNknWalletScreen.routeName);
                                },
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(top: 16, left: 30, right: 30),
                              child: Button(
                                text: NMobileLocalizations.of(context).no_wallet_import,
                                backgroundColor: Color(0xFF232D50),
                                onPressed: () {
//                                  locator<NavigateService>().pushNamed(ImportNknWalletScreen.routeName);
                                  Navigator.pushNamed(context, ImportNknWalletScreen.routeName);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              child: Opacity(
                opacity: 0.25,
                child: Image(
                  image: AssetImage('assets/header-background.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

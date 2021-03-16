import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/wallet/create_nkn_wallet.dart';
import 'package:nmobile/screens/wallet/import_nkn_eth_wallet.dart';
import 'package:nmobile/utils/extensions.dart';

class NoWalletScreen extends StatefulWidget {
  static const String routeName = '/no_wallet';

  @override
  _NoWalletScreenState createState() => _NoWalletScreenState();
}

class _NoWalletScreenState extends State<NoWalletScreen> {
  final GetIt locator = GetIt.instance;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context);
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
                  height: screenSize.size.height -
                      screenSize.padding.top -
                      screenSize.padding.bottom,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        flex: 0,
                        child: Padding(
                          padding: EdgeInsets.only(),
                          child: Image(
                              image: AssetImage('assets/wallet/pig.png'),
                              width: 120),
                        ),
                      ),
                      Expanded(
                        flex: 0,
                        child: Column(
                          children: <Widget>[
                            Label(
                              NL10ns.of(context).no_wallet_title,
                              type: LabelType.h2,
                              dark: true,
                            ),
                            Padding(
                              padding:
                                  EdgeInsets.only(top: 16, left: 24, right: 24),
                              child: Label(
                                NL10ns.of(context).no_wallet_desc,
                                type: LabelType.h4,
                                dark: true,
                                softWrap: true,
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
                            Button(
                              text: NL10ns.of(context).no_wallet_create,
                              onPressed: () {
//                                  locator<NavigateService>().pushNamed(CreateNknWalletScreen.routeName);
                                Navigator.pushNamed(
                                    context, CreateNknWalletScreen.routeName);
                              },
                            ),
                            Button(
                              text: NL10ns.of(context).no_wallet_import,
                              backgroundColor: Color(0xFF232D50),
                              onPressed: () {
//                                  locator<NavigateService>().pushNamed(ImportNknWalletScreen.routeName);
                                Navigator.pushNamed(
                                    context, ImportWalletScreen.routeName,
                                    arguments: WalletType.nkn);
                              },
                            ).pad(t: 12),
                          ],
                        ).pad(l: 20, r: 20),
                      ),
                    ],
                  ).pad(t: 60, b: 60),
                ),
              ),
            ),
          ),
          /*Positioned(
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
          ),*/
        ],
      ),
    );
  }
}

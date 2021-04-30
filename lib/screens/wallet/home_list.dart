import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/wallet/item.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/assets.dart';

class WalletHomeListScreen extends StatefulWidget {
  static const String routeName = '/wallet/home_list';

  @override
  _WalletHomeListScreenState createState() => _WalletHomeListScreenState();
}

class _WalletHomeListScreenState extends State<WalletHomeListScreen> {
  // TODO:GG params
  // WalletsBloc _walletsBloc;
  // StreamSubscription _walletSubscription;
  // final GetIt locator = GetIt.instance;
  //
  // double _totalNkn = 0;
  bool _allBackedUp = false;
  //
  // // ignore: non_constant_identifier_names
  // LOG _LOG;

  @override
  void initState() {
    super.initState();
    // TODO:GG bloc
//     _LOG = LOG(tag);
//     locator<TaskService>().queryNknWalletBalanceTask();
//     _walletsBloc = BlocProvider.of<WalletsBloc>(Global.appContext);
//     _walletSubscription = _walletsBloc.listen((state) {
//       if (state is WalletsLoaded) {
//         _totalNkn = 0;
//         _allBackedUp = true;
//         state.wallets.forEach((w) => _totalNkn += w.balance ?? 0);
//         state.wallets.forEach((w) {
// //          NLog.d('w.isBackedUp: ${w.isBackedUp}, w.name: ${w.name}');
//           _allBackedUp = w.isBackedUp && _allBackedUp;
//         });
//         setState(() {
// //          NLog.d('_allBackedUp: $_allBackedUp');
//         });
//       }
//     });
  }

  @override
  void dispose() {
    // TODO:GG bloc
    // _walletSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);

    return Layout(
      headerColor: application.theme.primaryColor,
      header: Header(
        titleChild: Padding(
          padding: EdgeInsets.only(left: 20),
          child: Label(
            _localizations.my_wallets,
            type: LabelType.h2,
            color: application.theme.fontLightColor,
          ),
        ),
        childTail: notBackedUpTip(context),
        actions: [
          PopupMenuButton(
            icon: assetIcon('more', width: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onSelected: (int result) async {
              switch (result) {
                case 0:
                  // TODO:GG create wallet
                  // final type = await SelectWalletTypeDialog.of(context).show();
                  // _LOG.i('WalletType:$type');
                  // if (type == WalletType.nkn) {
                  //   Navigator.of(context).pushNamed(CreateNknWalletScreen.routeName);
                  // } else if (type == WalletType.eth) {
                  //   Navigator.of(context).pushNamed(CreateEthWalletScreen.routeName);
                  // } else {
                  //   // nothing...
                  // }
                  break;
                case 1:
                  // TODO:GG import wallet
                  // final type = await SelectWalletTypeDialog.of(context).show();
                  // assert(type == WalletType.nkn || type == WalletType.eth);
                  // Navigator.of(context).pushNamed(ImportWalletScreen.routeName, arguments: type);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
              PopupMenuItem<int>(
                value: 0,
                child: Label(
                  _localizations.no_wallet_create,
                  type: LabelType.display,
                ),
              ),
              PopupMenuItem<int>(
                value: 1,
                child: Label(
                  _localizations.import_wallet,
                  type: LabelType.display,
                ),
              ),
            ],
          ),
        ],
      ),
      child: ListView.builder(
        padding: EdgeInsets.only(top: 22, bottom: 86),
        itemCount: 10, // TODO:GG item count
        // itemCount: state.wallets.length,
        itemBuilder: (context, index) {
          // WalletSchema w = state.wallets[index];
          WalletSchema w = WalletSchema(); // TODO:GG item scheme
          return Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: application.theme.backgroundLightColor,
              ),
              padding: EdgeInsets.only(left: 16, right: 16),
              child: WalletItem(schema: w, type: w.type == WalletType.nkn ? WalletType.nkn : WalletType.eth),
            ),
          );
        },
      ),
    );
  }

  Widget notBackedUpTip(BuildContext context) {
    S _localizations = S.of(context);

    return _allBackedUp
        ? SizedBox.shrink()
        : TextButton(
            onPressed: _onNotBackedUpTipClicked,
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.warning_rounded,
                  color: Color(0xFFF5B800),
                  size: 20,
                ),
                SizedBox(width: 4),
                Text(
                  _localizations.not_backed_up,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: SkinTheme.bodySmallFontSize, color: application.theme.strongColor),
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  maxLines: 1,
                ),
              ],
            ),
            // onPressed: _onNotBackedUpTipClicked,
          );
  }

  _onNotBackedUpTipClicked() {
    // WalletNotBackedUpDialog.of(context).show(() {
    //   BottomDialog.of(context).showSelectWalletDialog(title: NL10ns.of(context).select_asset_to_backup, callback: _listen);
    // });
  }

// _listen(WalletSchema ws) {
//   NLog.d(ws);
//   Future(() async {
//     final future = ws.getPassword();
//     future.then((password) async {
//       if (password != null) {
//         if (ws.type == WalletSchema.ETH_WALLET) {
//           String keyStore = await ws.getKeystore();
//           EthWallet ethWallet = Ethereum.restoreWallet(name: ws.name, keystore: keyStore, password: password);
//           Navigator.of(context).pushNamed(NknWalletExportScreen.routeName, arguments: {
//             'wallet': null,
//             'keystore': ethWallet.keystore,
//             'address': (await ethWallet.address).hex,
//             'publicKey': ethWallet.pubkeyHex,
//             'seed': ethWallet.privateKeyHex,
//             'name': ethWallet.name,
//           });
//         } else {
//           try {
//             var wallet = await ws.exportWallet(password);
//             if (wallet['address'] == ws.address) {
//               Navigator.of(context).pushNamed(NknWalletExportScreen.routeName, arguments: {
//                 'wallet': wallet,
//                 'keystore': wallet['keystore'],
//                 'address': wallet['address'],
//                 'publicKey': wallet['publicKey'],
//                 'seed': wallet['seed'],
//                 'name': ws.name,
//               });
//             } else {
//               showToast(NL10ns.of(context).password_wrong);
//             }
//           } catch (e) {
//             if (e.message == ConstUtils.WALLET_PASSWORD_ERROR) {
//               showToast(NL10ns.of(context).password_wrong);
//             }
//           }
//         }
//       }
//     });
//   });
// }
}

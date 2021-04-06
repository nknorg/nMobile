import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get_it/get_it.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/select_wallet_type.dart';
import 'package:nmobile/components/dialog/wallet_not_backed_up.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/wallet/item.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/eth_erc20_token.dart';
import 'package:nmobile/model/entity/wallet.dart';
import 'package:nmobile/screens/chat/authentication_helper.dart';
import 'package:nmobile/screens/wallet/create_eth_wallet.dart';
import 'package:nmobile/screens/wallet/create_nkn_wallet.dart';
import 'package:nmobile/screens/wallet/import_nkn_eth_wallet.dart';
import 'package:nmobile/screens/wallet/nkn_wallet_export.dart';
import 'package:nmobile/services/task_service.dart';
import 'package:nmobile/utils/const_utils.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:oktoast/oktoast.dart';

class WalletHome extends StatefulWidget {
  static const String routeName = '/wallet/home';

  @override
  _WalletHomeState createState() => _WalletHomeState();
}

class _WalletHomeState extends State<WalletHome>
    with SingleTickerProviderStateMixin, Tag {
  WalletsBloc _walletsBloc;
  StreamSubscription _walletSubscription;
  final GetIt locator = GetIt.instance;

  double _totalNkn = 0;
  bool _allBackedUp = true;

  // ignore: non_constant_identifier_names
  LOG _LOG;

  @override
  void initState() {
    super.initState();
    _LOG = LOG(tag);
    locator<TaskService>().queryNknWalletBalanceTask();
    _walletsBloc = BlocProvider.of<WalletsBloc>(Global.appContext);
    _walletSubscription = _walletsBloc.listen((state) {
      if (state is WalletsLoaded) {
        _totalNkn = 0;
        _allBackedUp = true;
        state.wallets.forEach((w) => _totalNkn += w.balance ?? 0);
        state.wallets.forEach((w) {
//          NLog.d('w.isBackedUp: ${w.isBackedUp}, w.name: ${w.name}');
          _allBackedUp = w.isBackedUp && _allBackedUp;
        });
        setState(() {
//          NLog.d('_allBackedUp: $_allBackedUp');
        });
      }
    });
  }

  @override
  void dispose() {
    _walletSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.primaryColor,
      appBar: Header(
        titleChild: Padding(
          padding: 0.pad(l: 20),
          child: Label(
            NL10ns.of(context).my_wallets,
            type: LabelType.h2,
          ),
        ),
        hasBack: false,
        notBackedUpTip: notBackedUpTip(context),
        backgroundColor: DefaultTheme.primaryColor,
        action: PopupMenuButton(
          icon: loadAssetIconsImage('more', width: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onSelected: (int result) async {
            switch (result) {
              case 0:
                final type = await SelectWalletTypeDialog.of(context).show();
                _LOG.i('WalletType:$type');
                if (type == WalletType.nkn) {
                  Navigator.of(context)
                      .pushNamed(CreateNknWalletScreen.routeName);
                } else if (type == WalletType.eth) {
                  Navigator.of(context)
                      .pushNamed(CreateEthWalletScreen.routeName);
                } else {
                  // nothing...
                }
                break;
              case 1:
                final type = await SelectWalletTypeDialog.of(context).show();
                assert(type == WalletType.nkn || type == WalletType.eth);
                Navigator.of(context)
                    .pushNamed(ImportWalletScreen.routeName, arguments: type);
                break;
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
            PopupMenuItem<int>(
              value: 0,
              child: Label(
                NL10ns.of(context).no_wallet_create,
                type: LabelType.display,
              ),
            ),
            PopupMenuItem<int>(
              value: 1,
              child: Label(
                NL10ns.of(context).import_wallet,
                type: LabelType.display,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: BodyBox(
          padding: const EdgeInsets.only(top: 4, left: 20, right: 20),
          child: BlocBuilder<WalletsBloc, WalletsState>(
            builder: (context, state) {
              if (state is WalletsLoaded) {
                return ListView.builder(
                    padding: EdgeInsets.only(top: 14.h),
                    itemCount: state.wallets.length,
                    itemBuilder: (context, index) {
                      WalletSchema w = state.wallets[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: WalletItem(
                            schema: w,
                            index: index,
                            type: w.type == WalletSchema.NKN_WALLET
                                ? WalletType.nkn
                                : WalletType.eth),
                      );
                    });
              }
              return ListView();
            },
          ),
        ),
      ),
    );
  }

  Widget notBackedUpTip(BuildContext context) {
    return _allBackedUp
        ? Space.empty
        : FlatButton(
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 20,
                  height: 20,
                  child: SvgPicture.asset('assets/icons/warning_20.svg',
                      color: Colours.yellow_f0),
                ),
                Text(
                  NL10ns.of(context).not_backed_up,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: DefaultTheme.bodySmallFontSize,
                      fontStyle: FontStyle.italic,
                      color: Colours.pink_f8),
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  maxLines: 1,
                ).pad(l: 4),
              ],
            ),
            padding: 0.pad(),
            onPressed: _onNotBackedUpTipClicked,
          );
  }

  _onNotBackedUpTipClicked() {
    // Don't use `context` as `Widget build(BuildContext context)`.
    WalletNotBackedUpDialog.of(context).show(() {
      BottomDialog.of(context).showSelectWalletDialog(
          title: NL10ns.of(context).select_asset_to_backup, callback: _listen);
    });
  }

  _listen(WalletSchema ws) {
    NLog.d(ws);
    Future(() async {
      final future = ws.getPassword();
      future.then((password) async {
        if (password != null) {
          if (ws.type == WalletSchema.ETH_WALLET) {
            String keyStore = await ws.getKeystore();
            EthWallet ethWallet = Ethereum.restoreWallet(
                name: ws.name, keystore: keyStore, password: password);
            Navigator.of(context)
                .pushNamed(NknWalletExportScreen.routeName, arguments: {
              'wallet': null,
              'keystore': ethWallet.keystore,
              'address': (await ethWallet.address).hex,
              'publicKey': ethWallet.pubkeyHex,
              'seed': ethWallet.privateKeyHex,
              'name': ethWallet.name,
            });
          } else {
            try {
              var wallet = await ws.exportWallet(password);
              if (wallet['address'] == ws.address) {
                Navigator.of(context)
                    .pushNamed(NknWalletExportScreen.routeName, arguments: {
                  'wallet': wallet,
                  'keystore': wallet['keystore'],
                  'address': wallet['address'],
                  'publicKey': wallet['publicKey'],
                  'seed': wallet['seed'],
                  'name': ws.name,
                });
              } else {
                showToast(NL10ns.of(context).password_wrong);
              }
            } catch (e) {
              if (e.message == ConstUtils.WALLET_PASSWORD_ERROR) {
                showToast(NL10ns.of(context).password_wrong);
              }
            }
          }
        }
      });
    });
  }
}

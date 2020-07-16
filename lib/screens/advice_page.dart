import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/select_list/select_list_item.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/view/dialog_confirm.dart';
import 'package:nmobile/utils/const_utils.dart';

class AdvancePage extends StatefulWidget {
  static const String routeName = '/advancepage';

  @override
  _AdvancedPageState createState() => _AdvancedPageState();
}

class _AdvancedPageState extends State<AdvancePage> {
  String title;
  String selectedValue;
  List<SelectListItem> list;
  final LocalStorage _localStorage = LocalStorage();

  @override
  void initState() {
    super.initState();
    initAsync();
  }

  String _cacheSize;
  String _dbSize;

  initAsync() async {
    var size = await getTotalSizeOfCacheFile(Global.applicationRootDirectory);
    var dbs = await getTotalSizeOfDbFile(Global.applicationRootDirectory);
    setState(() {
      _cacheSize = Format.formatSize(size);
      _dbSize = Format.formatSize(dbs);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        title: NMobileLocalizations.of(context).storage_text,
        backgroundColor: DefaultTheme.backgroundColor4,
      ),
      body: Builder(
        builder: (BuildContext context) => BodyBox(
          padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
          child: Flex(
            direction: Axis.vertical,
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  color: DefaultTheme.backgroundLightColor,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FlatButton(
                        padding: const EdgeInsets.only(left: 16, right: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                        onPressed: () async {
                          SimpleConfirm(
                              context: context,
                              content: NMobileLocalizations.of(context).delete_cache_confirm_title,
                              buttonText: NMobileLocalizations.of(context).delete,
                              buttonColor: Colors.red,
                              callback: (v) {
                                if (v) {
                                  Timer(Duration(milliseconds: 200), () async {
                                    var walletData = await _localStorage.getItem(LocalStorage.NKN_WALLET_KEY, 0);
                                    var wallet = WalletSchema(name: walletData['name'], address: walletData['address']);
                                    var password = await wallet.getPassword();
                                    if (password != null) {
                                      try {
                                        var w = await wallet.exportWallet(password);
                                        await clearCacheFile(Global.applicationRootDirectory);
                                        var size = await getTotalSizeOfCacheFile(Global.applicationRootDirectory);
                                        setState(() {
                                          _cacheSize = Format.formatSize(size);
                                        });
                                      } catch (e) {
                                        if (e.message == ConstUtils.WALLET_PASSWORD_ERROR) {
                                          ModalDialog.of(context).show(
                                            height: 240,
                                            content: Label(
                                              NMobileLocalizations.of(context).password_wrong,
                                              type: LabelType.bodyRegular,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  });
                                }
                              }).show();
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Label(
                              NMobileLocalizations.of(context).clear_cache,
                              type: LabelType.bodyRegular,
                              color: DefaultTheme.fontColor1,
                              height: 1,
                            ),
                            Row(
                              children: <Widget>[
                                Label(
                                  _cacheSize ?? '',
                                  type: LabelType.bodyRegular,
                                  color: DefaultTheme.fontColor2,
                                  height: 1,
                                ),
                                SvgPicture.asset(
                                  'assets/icons/right.svg',
                                  width: 24,
                                  color: DefaultTheme.fontColor2,
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FlatButton(
                        padding: const EdgeInsets.only(left: 16, right: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))),
                        onPressed: () async {
                          SimpleConfirm(
                              context: context,
                              content: NMobileLocalizations.of(context).delete_db_confirm_title,
                              buttonText: NMobileLocalizations.of(context).delete,
                              buttonColor: Colors.red,
                              callback: (v) {
                                if (v) {
                                  Timer(Duration(milliseconds: 200), () async {
                                    var walletData = await _localStorage.getItem(LocalStorage.NKN_WALLET_KEY, 0);
                                    var wallet = WalletSchema(name: walletData['name'], address: walletData['address']);
                                    var password = await wallet.getPassword();
                                    if (password != null) {
                                      try {
                                        var w = await wallet.exportWallet(password);
                                        await clearDbFile(Global.applicationRootDirectory);
                                        var size = await getTotalSizeOfDbFile(Global.applicationRootDirectory);
                                        setState(() {
                                          _dbSize = Format.formatSize(size);
                                        });
                                      } catch (e) {
                                        if (e.message == ConstUtils.WALLET_PASSWORD_ERROR) {
                                          ModalDialog.of(context).show(
                                            height: 240,
                                            content: Label(
                                              NMobileLocalizations.of(context).password_wrong,
                                              type: LabelType.bodyRegular,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  });
                                }
                              }).show();
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Label(
                              NMobileLocalizations.of(context).clear_database + ' [debug]',
                              type: LabelType.bodyRegular,
                              color: DefaultTheme.fontColor1,
                              height: 1,
                            ),
                            Row(
                              children: <Widget>[
                                Label(
                                  _dbSize ?? '',
                                  type: LabelType.bodyRegular,
                                  color: DefaultTheme.fontColor2,
                                  height: 1,
                                ),
                                SvgPicture.asset(
                                  'assets/icons/right.svg',
                                  width: 24,
                                  color: DefaultTheme.fontColor2,
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
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

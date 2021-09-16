import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/screens/common/select.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/cache.dart';
import 'package:nmobile/utils/format.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class FileType {
  static const cache = 0;
  static const db = 1;
}

class SettingsCacheScreen extends BaseStateFulWidget {
  static const String routeName = '/settings/cache';

  @override
  _SettingsCacheScreenState createState() => _SettingsCacheScreenState();
}

class _SettingsCacheScreenState extends BaseStateFulWidgetState<SettingsCacheScreen> {
  String? title;
  String? selectedValue;
  List<SelectListItem>? list;

  String? _cacheSize;
  String? _dbSize;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
    _refreshFilesLength();
  }

  _refreshFilesLength() async {
    var size = await getTotalSizeOfCacheFile(Global.applicationRootDirectory);
    var databasesPath = Directory(await getDatabasesPath());
    var dbs = await getTotalSizeOfDbFile(databasesPath);
    setState(() {
      _cacheSize = formatFlowSize(size, unitArr: ['B', 'KB', 'MB', 'GB']);
      _dbSize = formatFlowSize(dbs, unitArr: ['B', 'KB', 'MB', 'GB']);
    });
  }

  _clearCache(int type) async {
    // auth
    String? address = await walletCommon.getDefaultAddress();
    if (address == null || address.isEmpty) return;
    String? input = await authorization.getWalletPassword(address);
    if (input == null || input.isEmpty) {
      Toast.show(S.of(context).input_password);
      return;
    }
    if (!(await walletCommon.isPasswordRight(address, input))) {
      Toast.show(S.of(context).error_confirm_password);
      return;
    }
    // clear
    Loading.show();
    await clientCommon.signOut(closeDB: true);
    await Future.delayed(Duration(seconds: 1));
    if (type == FileType.cache) {
      await clearCacheFile(Global.applicationRootDirectory);
    } else if (type == FileType.db) {
      var databasesPath = Directory(await getDatabasesPath());
      await clearDbFile(databasesPath);
    }
    await _refreshFilesLength();
    Loading.dismiss();
    Toast.show(S.of(context).success);
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    return Layout(
      headerColor: application.theme.headBarColor2,
      header: Header(
        title: _localizations.cache,
        backgroundColor: application.theme.headBarColor2,
      ),
      body: Container(
        padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
        child: Column(
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: application.theme.backgroundLightColor,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Column(
                children: <Widget>[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      style: _buttonStyle(top: true),
                      onPressed: () async {
                        await ModalDialog.of(this.context).confirm(
                          titleWidget: Label(
                            _localizations.tips,
                            type: LabelType.h3,
                            softWrap: true,
                          ),
                          contentWidget: Label(
                            _localizations.delete_cache_confirm_title,
                            type: LabelType.bodyRegular,
                            softWrap: true,
                          ),
                          agree: Button(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Asset.iconSvg(
                                    'trash',
                                    color: application.theme.fontLightColor,
                                    width: 24,
                                  ),
                                ),
                                Label(
                                  _localizations.delete,
                                  type: LabelType.h3,
                                  color: application.theme.fontLightColor,
                                )
                              ],
                            ),
                            backgroundColor: application.theme.strongColor,
                            width: double.infinity,
                            onPressed: () {
                              Navigator.pop(context);
                              _clearCache(FileType.cache);
                            },
                          ),
                          reject: Button(
                            width: double.infinity,
                            text: _localizations.cancel,
                            fontColor: application.theme.fontColor2,
                            backgroundColor: application.theme.backgroundLightColor,
                            onPressed: () => Navigator.pop(context),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Label(
                            _localizations.clear_cache,
                            type: LabelType.bodyRegular,
                            color: application.theme.fontColor1,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                          Row(
                            children: <Widget>[
                              Label(
                                _cacheSize ?? '',
                                type: LabelType.bodyRegular,
                                color: application.theme.fontColor2,
                                height: 1,
                              ),
                              Asset.iconSvg(
                                'right',
                                width: 24,
                                color: application.theme.fontColor2,
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 0, color: application.theme.dividerColor),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      style: _buttonStyle(bottom: true),
                      onPressed: () async {
                        await ModalDialog.of(this.context).confirm(
                          titleWidget: Label(
                            _localizations.tips,
                            type: LabelType.h3,
                            softWrap: true,
                          ),
                          contentWidget: Label(
                            _localizations.delete_db_confirm_title,
                            type: LabelType.bodyRegular,
                            softWrap: true,
                          ),
                          agree: Button(
                            width: double.infinity,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Asset.iconSvg(
                                    'trash',
                                    color: application.theme.fontLightColor,
                                    width: 24,
                                  ),
                                ),
                                Label(
                                  _localizations.delete,
                                  type: LabelType.h3,
                                  color: application.theme.fontLightColor,
                                )
                              ],
                            ),
                            backgroundColor: application.theme.strongColor,
                            onPressed: () {
                              Navigator.pop(context);
                              _clearCache(FileType.db);
                            },
                          ),
                          reject: Button(
                            width: double.infinity,
                            text: _localizations.cancel,
                            fontColor: application.theme.fontColor2,
                            backgroundColor: application.theme.backgroundLightColor,
                            onPressed: () => Navigator.pop(context),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Label(
                            _localizations.clear_database + ' [debug]',
                            type: LabelType.bodyRegular,
                            color: application.theme.fontColor1,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                          Row(
                            children: <Widget>[
                              Label(
                                _dbSize ?? '',
                                type: LabelType.bodyRegular,
                                color: application.theme.fontColor2,
                                height: 1,
                              ),
                              Asset.iconSvg(
                                'right',
                                width: 24,
                                color: application.theme.fontColor2,
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
    );
  }

  _buttonStyle({bool top = false, bool bottom = false}) {
    return ButtonStyle(
      padding: MaterialStateProperty.resolveWith((states) => EdgeInsets.only(left: 16, right: 16)),
      shape: MaterialStateProperty.resolveWith(
        (states) => RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: top ? Radius.circular(12) : Radius.zero, bottom: bottom ? Radius.circular(12) : Radius.zero)),
      ),
    );
  }
}

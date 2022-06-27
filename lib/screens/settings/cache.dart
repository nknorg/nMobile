import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/db/db.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/common/select.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/path.dart';

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
    double cacheSize = await _getTotalSizeOfFile(Global.applicationRootDirectory, dirFilter: DirType.cache);
    double dbSize = await _getTotalSizeOfFile(Directory(await dbCommon.getDBDirPath()), filePrefix: DB.NKN_DATABASE_NAME);
    setState(() {
      _cacheSize = Format.flowSize(cacheSize, unitArr: ['B', 'KB', 'MB', 'GB']);
      _dbSize = Format.flowSize(dbSize, unitArr: ['B', 'KB', 'MB', 'GB']);
    });
  }

  Future<double> _getTotalSizeOfFile(final FileSystemEntity file, {String? dirFilter, String? filePrefix, bool can = false}) async {
    List<String> splits = file.path.split("/");
    if (splits.length <= 0) return 0;
    String dirName = splits[splits.length - 1];
    if (!can) {
      if (dirFilter?.isNotEmpty == true) {
        can = (file is Directory) && (dirName == dirFilter);
      } else if (filePrefix?.isNotEmpty == true) {
        can = (file is File) && (dirName.startsWith(filePrefix!));
      } else {
        can = true;
      }
    }
    if (file is Directory) {
      double total = 0;
      final List<FileSystemEntity> children = file.listSync();
      for (final FileSystemEntity child in children) {
        total += await _getTotalSizeOfFile(child, can: can, dirFilter: dirFilter, filePrefix: filePrefix);
      }
      return total;
    }
    if (file is File) {
      if (can) {
        int length = await file.length();
        return double.tryParse(length.toString()) ?? 0;
      }
      return 0;
    }
    return 0;
  }

  Future<bool> _delete(FileSystemEntity file) async {
    // if (path == null || path.isEmpty) return false;
    // File file = File(path);
    if (file.existsSync()) {
      file.deleteSync(recursive: true);
      return true;
    }
    return false;
  }

  _clearCache(int type) async {
    // wallet
    WalletSchema? wallet = await walletCommon.getDefault();
    if (wallet == null || wallet.publicKey.isEmpty == true) {
      wallet = await BottomDialog.of(Global.appContext).showWalletSelect(
        title: Global.locale((s) => s.select_another_wallet, ctx: context),
        onlyNKN: true,
      );
    }
    // pwd
    String? address = wallet?.address;
    if (wallet == null || address == null || address.isEmpty) return;
    String? pwd = await authorization.getWalletPassword(address);
    if (pwd == null || pwd.isEmpty) {
      Toast.show(Global.locale((s) => s.input_password, ctx: context));
      return;
    }
    if (!(await walletCommon.isPasswordRight(address, pwd))) {
      Toast.show(Global.locale((s) => s.error_confirm_password, ctx: context));
      return;
    }
    // pubKey
    String pubKey = wallet.publicKey;
    if (pubKey.isEmpty) {
      String? pk = await getPubKeyFromWallet(wallet.address, pwd);
      if (pk == null || pk.isEmpty) return;
      pubKey = pk;
    }
    // delete
    Loading.show();
    if (type == FileType.cache) {
      String path1 = Path.getDir(null, DirType.cache);
      String path2 = Path.getDir(pubKey, DirType.cache);
      await _delete(Directory(path1));
      await _delete(Directory(path2));
    } else if (type == FileType.db) {
      await clientCommon.signOut(clearWallet: true, closeDB: true);
      await Future.delayed(Duration(seconds: 1));
      String dbPath = await dbCommon.getDBFilePath(pubKey);
      await _delete(File(dbPath));
    }
    // refresh
    await Future.delayed(Duration(milliseconds: 100));
    await _refreshFilesLength();
    Loading.dismiss();
    Toast.show(Global.locale((s) => s.success, ctx: context));
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.headBarColor2,
      header: Header(
        title: Global.locale((s) => s.cache, ctx: context),
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
                        await ModalDialog.of(Global.appContext).confirm(
                          titleWidget: Label(
                            Global.locale((s) => s.tips, ctx: context),
                            type: LabelType.h3,
                            softWrap: true,
                          ),
                          contentWidget: Label(
                            Global.locale((s) => s.delete_cache_confirm_title, ctx: context),
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
                                  Global.locale((s) => s.delete, ctx: context),
                                  type: LabelType.h3,
                                  color: application.theme.fontLightColor,
                                )
                              ],
                            ),
                            backgroundColor: application.theme.strongColor,
                            width: double.infinity,
                            onPressed: () {
                              if (Navigator.of(context).canPop()) Navigator.pop(context);
                              _clearCache(FileType.cache);
                            },
                          ),
                          reject: Button(
                            width: double.infinity,
                            text: Global.locale((s) => s.cancel, ctx: context),
                            fontColor: application.theme.fontColor2,
                            backgroundColor: application.theme.backgroundLightColor,
                            onPressed: () {
                              if (Navigator.of(context).canPop()) Navigator.pop(context);
                            },
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Label(
                            Global.locale((s) => s.clear_cache, ctx: context),
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
                        await ModalDialog.of(Global.appContext).confirm(
                          titleWidget: Label(
                            Global.locale((s) => s.tips, ctx: context),
                            type: LabelType.h3,
                            softWrap: true,
                          ),
                          contentWidget: Label(
                            Global.locale((s) => s.delete_db_confirm_title, ctx: context),
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
                                  Global.locale((s) => s.delete, ctx: context),
                                  type: LabelType.h3,
                                  color: application.theme.fontLightColor,
                                )
                              ],
                            ),
                            backgroundColor: application.theme.strongColor,
                            onPressed: () {
                              if (Navigator.of(context).canPop()) Navigator.pop(context);
                              _clearCache(FileType.db);
                            },
                          ),
                          reject: Button(
                            width: double.infinity,
                            text: Global.locale((s) => s.cancel, ctx: context),
                            fontColor: application.theme.fontColor2,
                            backgroundColor: application.theme.backgroundLightColor,
                            onPressed: () {
                              if (Navigator.of(context).canPop()) Navigator.pop(context);
                            },
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Label(
                            Global.locale((s) => s.clear_database + ' [debug]', ctx: context),
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

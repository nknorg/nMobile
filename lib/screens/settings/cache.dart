import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/db.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/asset.dart';
import 'package:nmobile/utils/cache.dart';
import 'package:nmobile/utils/format.dart';

import '../common/select.dart';

class CacheScreen extends StatefulWidget {
  static const String routeName = '/settings/cache';

  @override
  _CacheScreenState createState() => _CacheScreenState();
}

class _CacheScreenState extends State<CacheScreen> {
  String title;
  String selectedValue;
  List<SelectListItem> list;

  String _cacheSize;
  String _dbSize;

  @override
  void initState() {
    super.initState();
    initAsync();
  }

  _buttonStyle({bool top = false, bool bottom = false}) {
    return ButtonStyle(
      padding: MaterialStateProperty.resolveWith((states) => EdgeInsets.only(left: 16, right: 16)),
      shape: MaterialStateProperty.resolveWith(
        (states) => RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: top ? Radius.circular(12) : Radius.zero, bottom: bottom ? Radius.circular(12) : Radius.zero)),
      ),
    );
  }

  initAsync() async {
    var size = await getTotalSizeOfCacheFile(Global.applicationRootDirectory);
    var dbs = await getTotalSizeOfDbFile(Global.applicationRootDirectory);
    setState(() {
      _cacheSize = formatFlowSize(size, unitArr: ['B', 'KB', 'MB', 'GB']);
      _dbSize = formatFlowSize(dbs, unitArr: ['B', 'KB', 'MB', 'GB']);
    });
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
        child: Flex(
          direction: Axis.vertical,
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
                        await ModalDialog.of(context).confirm(
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
                            onPressed: () async {
                              // todo
                            },
                          ),
                          reject: Button(
                            backgroundColor: application.theme.backgroundLightColor,
                            fontColor: application.theme.fontColor2,
                            text: _localizations.cancel,
                            width: double.infinity,
                            onPressed: () => Navigator.of(context).pop(),
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
                        await ModalDialog.of(context).confirm(
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
                            onPressed: () async {
                              // todo auth
                              await DB.currentDatabase?.close();
                              await clearDbFile(Global.applicationRootDirectory);
                              var size = await getTotalSizeOfDbFile(Global.applicationRootDirectory);
                              setState(() {
                                _dbSize = formatFlowSize(size, unitArr: ['B', 'KB', 'MB', 'GB']);
                              });
                              Navigator.of(context).pop();
                            },
                          ),
                          reject: Button(
                            backgroundColor: application.theme.backgroundLightColor,
                            fontColor: application.theme.fontColor2,
                            text: _localizations.cancel,
                            width: double.infinity,
                            onPressed: () => Navigator.of(context).pop(),
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
}

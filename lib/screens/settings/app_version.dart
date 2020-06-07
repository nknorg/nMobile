import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/dialog/apk_upgrade_notes.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/screens/settings/app_upgrade.dart';
import 'package:nmobile/utils/extensions.dart';

class AppVersion extends StatelessWidget {
  static const String routeName = '/settings/app_version';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.primaryColor,
      appBar: Header(
        titleChild: Label(
          NMobileLocalizations.of(context).app_version,
          type: LabelType.h4,
        ),
        hasBack: true,
        backgroundColor: DefaultTheme.primaryColor,
      ),
      body: BodyBox(
        padding: const EdgeInsets.only(top: 4, left: 20, right: 20),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              !Platform.isAndroid
                  ? Space.empty
                  : SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FlatButton(
                          onPressed: () {
                            UpgradeChecker.checkUpgrade(context, (showNotes, versionCode, title, notes, force, jsonMap) {
                              if (showNotes) {
                                ApkUpgradeNotesDialog.of(context).show(versionCode, title, notes, force, jsonMap, (jsonMap) {
                                  UpgradeChecker.downloadApkFile(jsonMap, (progress) {
                                    // TODO:
                                    print('downloadApkFile progress: $progress%');
                                  });
                                }, (versionCode) {
                                  UpgradeChecker.setVersionIgnoredOrInstalled(versionCode);
                                });
                              }
                            });
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                NMobileLocalizations.of(context).check_upgrade,
                                style: TextStyle(color: Colours.blue_0f),
                              ),
                            ],
                          )),
                    ).pad(t: 32),
            ],
          ),
        ),
      ),
    );
  }
}

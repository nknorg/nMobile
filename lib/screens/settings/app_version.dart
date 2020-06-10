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
import 'package:oktoast/oktoast.dart';

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
                            showToast(NMobileLocalizations.of(context).check_upgrade, duration: Duration(seconds: 3));
                            UpgradeChecker.checkUpgrade(context, false, (showNotes, version, title, notes, force, jsonMap) {
                              if (showNotes) {
                                var bloc;
                                bloc = ApkUpgradeNotesDialog.of(context).show(version, title, notes, force, jsonMap, (jsonMap) {
                                  UpgradeChecker.downloadApkFile(jsonMap, (progress) {
                                    bloc.add(progress);
                                  });
                                }, (version) {
                                  UpgradeChecker.setVersionIgnored(version);
                                }, () {
                                  UpgradeChecker.setDialogDismissed();
                                });
                              }
                            }, onAlreadyTheLatestVersion: () {
                              showToast(NMobileLocalizations.of(context).already_the_latest_version);
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

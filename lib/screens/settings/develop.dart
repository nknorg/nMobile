import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/screens/settings/files.dart';
import 'package:nmobile/screens/settings/cross_send_policy.dart';
import 'package:nmobile/screens/settings/push_token_debug.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/utils/asset.dart';

class SettingsDevelopScreen extends BaseStateFulWidget {
  static const String routeName = '/settings/develop';

  @override
  _SettingsDevelopScreenState createState() => _SettingsDevelopScreenState();
}

class _SettingsDevelopScreenState extends BaseStateFulWidgetState<SettingsDevelopScreen> {
  bool _bubbleEnable = false;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
    _refreshSettings();
  }

  _refreshSettings() async {
    var msgDebug = await SettingsStorage.getSettings(SettingsStorage.OPEN_DEVELOP_OPTIONS_MESSAGE_DEBUG);
    setState(() {
      _bubbleEnable = ((msgDebug?.toString() == "true") || (msgDebug == true));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.headBarColor2,
      header: Header(
        title: Settings.locale((s) => s.developer_options, ctx: context),
        backgroundColor: application.theme.headBarColor2,
      ),
      body: Container(
        padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: application.theme.backgroundLightColor,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Column(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: application.theme.backgroundLightColor,
                      ),
                      child: Column(
                        children: <Widget>[
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: TextButton(
                              style: _buttonStyle(),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Label(
                                    Settings.locale((s) => s.message_debug_info, ctx: context),
                                    type: LabelType.bodyRegular,
                                    color: application.theme.fontColor1,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                                  Row(
                                    children: <Widget>[
                                      CupertinoSwitch(
                                          value: _bubbleEnable,
                                          activeTrackColor: application.theme.primaryColor,
                                          onChanged: (bool value) async {
                                            Settings.messageDebugInfo = value;
                                            SettingsStorage.setSettings('${SettingsStorage.OPEN_DEVELOP_OPTIONS_MESSAGE_DEBUG}', value);
                                            setState(() {
                                              _bubbleEnable = value;
                                            });
                                          }),
                                    ],
                                  ),
                                ],
                              ),
                              onPressed: () {

                              },
                            ),
                          ),
                          Divider(height: 0, color: application.theme.dividerColor),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: TextButton(
                              style: _buttonStyle(bottom: false),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Label(
                                    Settings.locale((s) => s.cross_send_policy, ctx: context),
                                    type: LabelType.bodyRegular,
                                    color: application.theme.fontColor1,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                                  Row(
                                    children: <Widget>[
                                      Asset.iconSvg(
                                        'right',
                                        width: 24,
                                        color: application.theme.fontColor2,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              onPressed: () {
                                Navigator.pushNamed(context, SettingsCrossSendPolicyScreen.routeName);
                              },
                            ),
                          ),
                          Divider(height: 0, color: application.theme.dividerColor),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: TextButton(
                              style: _buttonStyle(bottom: false),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Label(
                                    'Push / Device Token',
                                    type: LabelType.bodyRegular,
                                    color: application.theme.fontColor1,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                                  Row(
                                    children: <Widget>[
                                      Asset.iconSvg(
                                        'right',
                                        width: 24,
                                        color: application.theme.fontColor2,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              onPressed: () {
                                Navigator.pushNamed(context, SettingsPushTokenDebugScreen.routeName);
                              },
                            ),
                          ),
                          Divider(height: 0, color: application.theme.dividerColor),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: TextButton(
                              style: _buttonStyle(bottom: true),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Label(
                                    Settings.locale((s) => s.file_manager, ctx: context),
                                    type: LabelType.bodyRegular,
                                    color: application.theme.fontColor1,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                                  Row(
                                    children: <Widget>[
                                      Asset.iconSvg(
                                        'right',
                                        width: 24,
                                        color: application.theme.fontColor2,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              onPressed: () {
                                Navigator.pushNamed(context, SettingsFilesScreen.routeName);
                              },
                            ),
                          ),
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

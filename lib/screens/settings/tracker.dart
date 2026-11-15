import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/storages/settings.dart';

class SettingsTrackerScreen extends BaseStateFulWidget {
  static const String routeName = '/settings/tracker';

  @override
  _SettingsTrackerScreenState createState() => _SettingsTrackerScreenState();
}

class _SettingsTrackerScreenState extends BaseStateFulWidgetState<SettingsTrackerScreen> {
  bool _pushEnable = true;
  bool _bugEnable = true;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
    _refreshSettings();
  }

  _refreshSettings() async {
    var push = await SettingsStorage.getSettings(SettingsStorage.CLOSE_NOTIFICATION_PUSH_API);
    var bug = await SettingsStorage.getSettings(SettingsStorage.CLOSE_BUG_UPLOAD_API);
    setState(() {
      _pushEnable = !((push?.toString() == "true") || (push == true));
      _bugEnable = !((bug?.toString() == "true") || (bug == true));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.headBarColor2,
      header: Header(
        title: Settings.locale((s) => s.tracker, ctx: context),
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
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: TextButton(
                      style: _buttonStyle(top: true, bottom: true),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Label(
                            Settings.locale((s) => s.notification_push, ctx: context),
                            type: LabelType.bodyRegular,
                            color: application.theme.fontColor1,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                          Row(
                            children: <Widget>[
                              CupertinoSwitch(
                                  value: _pushEnable,
                                  activeTrackColor: application.theme.primaryColor,
                                  onChanged: (bool value) async {
                                    SettingsStorage.setSettings('${SettingsStorage.CLOSE_NOTIFICATION_PUSH_API}', !value);
                                    Settings.notificationPushEnable = value;
                                    setState(() {
                                      _pushEnable = value;
                                    });
                                  }),
                            ],
                          ),
                        ],
                      ),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 18, right: 18, top: 6),
              child: Label(
                Settings.locale((s) => _pushEnable ? s.allow_push_message_notifications_to_others : s.do_not_allow_push_message_notifications_to_others, ctx: context),
                type: LabelType.bodySmall,
                fontWeight: FontWeight.w600,
                softWrap: true,
              ),
            ),
            SizedBox(height: 28),
            Container(
              decoration: BoxDecoration(
                color: application.theme.backgroundLightColor,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Column(
                children: <Widget>[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: TextButton(
                      style: _buttonStyle(top: true, bottom: true),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Label(
                            Settings.locale((s) => s.error_tracking, ctx: context),
                            type: LabelType.bodyRegular,
                            color: application.theme.fontColor1,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                          Row(
                            children: <Widget>[
                              CupertinoSwitch(
                                  value: _bugEnable,
                                  activeTrackColor: application.theme.primaryColor,
                                  onChanged: (bool value) async {
                                    SettingsStorage.setSettings('${SettingsStorage.CLOSE_BUG_UPLOAD_API}', !value);
                                    Settings.sentryEnable = value;
                                    setState(() {
                                      _bugEnable = value;
                                    });
                                  }),
                            ],
                          ),
                        ],
                      ),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 18, right: 18, top: 6),
              child: Label(
                Settings.locale((s) => _bugEnable ? s.allow_uploading_application_exception_logs : s.do_not_allow_uploading_application_exception_logs, ctx: context),
                type: LabelType.bodySmall,
                fontWeight: FontWeight.w600,
                softWrap: true,
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

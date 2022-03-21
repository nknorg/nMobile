import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/settings/settings_bloc.dart';
import 'package:nmobile/blocs/settings/settings_event.dart';
import 'package:nmobile/blocs/settings/settings_state.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/common/select.dart';
import 'package:nmobile/screens/settings/cache.dart';
import 'package:nmobile/screens/settings/subscribe.dart';
import 'package:nmobile/storages/settings.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/utils.dart';

class SettingsHomeScreen extends BaseStateFulWidget {
  static const String routeName = '/settings';

  @override
  _SettingsHomeScreenState createState() => _SettingsHomeScreenState();
}

class _SettingsHomeScreenState extends BaseStateFulWidgetState<SettingsHomeScreen> with AutomaticKeepAliveClientMixin {
  SettingsBloc? _settingsBloc;
  StreamSubscription? _settingSubscription;

  String? _currentLanguage;
  String? _currentNotificationType;
  List<SelectListItem> _languageList = [];
  List<SelectListItem> _notificationTypeList = [];
  bool _biometricsSelected = false;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
    _settingsBloc = BlocProvider.of<SettingsBloc>(context);
    _settingSubscription = _settingsBloc?.stream.listen((state) async {
      if (state is LocaleUpdated) {
        setState(() {
          _currentLanguage = _getLanguageText(state.locale);
        });
        Future.delayed(Duration(milliseconds: 500), () {
          setState(() {
            _initData();
          });
        });
      }
    });

    _initData();

    _currentLanguage = _getLanguageText(Settings.locale);
    _biometricsSelected = Settings.biometricsAuthentication;
  }

  @override
  void dispose() {
    _settingSubscription?.cancel();
    super.dispose();
  }

  _initData() {
    _languageList = <SelectListItem>[
      SelectListItem(
        text: Global.locale((s) => s.language_auto),
        value: 'auto',
      ),
      SelectListItem(
        text: 'English',
        value: 'en',
      ),
      SelectListItem(
        text: '简体中文',
        value: 'zh',
      ),
      SelectListItem(
        text: '繁体中文',
        value: 'zh_Hant_CN',
      ),
    ];
    _notificationTypeList = <SelectListItem>[
      SelectListItem(
        text: Global.locale((s) => s.local_notification_only_name),
        value: NotificationType.only_name,
      ),
      SelectListItem(
        text: Global.locale((s) => s.local_notification_both_name_message),
        value: NotificationType.name_and_message,
      ),
      SelectListItem(
        text: Global.locale((s) => s.local_notification_none_display),
        value: NotificationType.none,
      ),
    ];
    _changeNotificationType();
  }

  String _getLanguageText(String? lang) {
    if (lang == null || lang.isEmpty || lang == 'auto') {
      return Global.locale((s) => s.language_auto);
    }
    try {
      return _languageList.firstWhere((x) => x.value == lang).text;
    } catch (e) {
      handleError(e);
      return Global.locale((s) => s.language_auto);
    }
  }

  _changeNotificationType() {
    setState(() {
      _currentNotificationType = _notificationTypeList.firstWhere((x) => x.value == Settings.notificationType).text;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Layout(
      headerColor: application.theme.primaryColor,
      header: Header(
        titleChild: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Label(
            Global.locale((s) => s.menu_settings, ctx: context),
            type: LabelType.h2,
            color: application.theme.fontLightColor,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 20, bottom: 100, left: 20, right: 20),
        children: [
          // general
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Label(
                  Global.locale((s) => s.general, ctx: context),
                  type: LabelType.h3,
                ),
              ],
            ),
          ),
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
                    onPressed: () async {
                      Navigator.pushNamed(context, SelectScreen.routeName, arguments: {
                        SelectScreen.title: Global.locale((s) => s.change_language, ctx: context),
                        SelectScreen.selectedValue: Settings.locale,
                        SelectScreen.list: _languageList,
                      }).then((lang) {
                        if ((lang != null) && (lang is String)) {
                          _settingsBloc?.add(UpdateLanguage(lang));
                        }
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Label(
                          Global.locale((s) => s.language, ctx: context),
                          type: LabelType.bodyRegular,
                          fontWeight: FontWeight.bold,
                          color: application.theme.fontColor1,
                          height: 1,
                        ),
                        Row(
                          children: <Widget>[
                            Label(
                              _currentLanguage ?? "",
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
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          //security
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 16),
            child: Row(
              children: <Widget>[
                Label(
                  Global.locale((s) => s.security, ctx: context),
                  type: LabelType.h3,
                ),
              ],
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
            ),
          ),
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
                          Global.locale((s) => s.biometrics, ctx: context),
                          type: LabelType.bodyRegular,
                          color: application.theme.fontColor1,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                        Row(
                          children: <Widget>[
                            CupertinoSwitch(
                                value: _biometricsSelected,
                                activeColor: application.theme.primaryColor,
                                onChanged: (bool value) async {
                                  WalletSchema? _wallet = await walletCommon.getDefault();
                                  if (_wallet == null || _wallet.address.isEmpty) {
                                    final wallets = await walletCommon.getWallets();
                                    if (wallets.isNotEmpty) _wallet = wallets[0];
                                  }
                                  if (_wallet == null || _wallet.address.isEmpty) {
                                    ModalDialog.of(Global.appContext).confirm(
                                      title: Global.locale((s) => s.wallet_missing),
                                      hasCloseButton: true,
                                    );
                                    return;
                                  }
                                  String? input = await BottomDialog.of(Global.appContext).showInput(
                                    title: Global.locale((s) => s.verify_wallet_password),
                                    inputTip: Global.locale((s) => s.wallet_password),
                                    inputHint: Global.locale((s) => s.input_password),
                                    actionText: Global.locale((s) => s.continue_text),
                                    validator: Validator.of(context).password(),
                                    password: true,
                                  );
                                  if (!(await walletCommon.isPasswordRight(_wallet.address, input))) {
                                    Toast.show(Global.locale((s) => s.tip_password_error));
                                    return;
                                  }
                                  Settings.biometricsAuthentication = value;
                                  SettingsStorage.setSettings('${SettingsStorage.BIOMETRICS_AUTHENTICATION}', value);
                                  setState(() {
                                    _biometricsSelected = value;
                                  });
                                })
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

          // notification
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 16),
            child: Row(
              children: <Widget>[
                Label(
                  Global.locale((s) => s.notification, ctx: context),
                  type: LabelType.h3,
                ),
              ],
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
            ),
          ),
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
                          Global.locale((s) => s.notification_type, ctx: context),
                          type: LabelType.bodyRegular,
                          color: application.theme.fontColor1,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                        Row(
                          children: <Widget>[
                            Label(
                              _currentNotificationType ?? "",
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
                        ),
                      ],
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, SelectScreen.routeName, arguments: {
                        SelectScreen.title: Global.locale((s) => s.local_notification),
                        SelectScreen.selectedValue: Settings.notificationType,
                        SelectScreen.list: _notificationTypeList,
                      }).then((type) {
                        if (type != null) {
                          Settings.notificationType = type as int;
                          SettingsStorage.setSettings('${SettingsStorage.NOTIFICATION_TYPE_KEY}', type);
                          setState(() {
                            _currentNotificationType = _notificationTypeList.firstWhere((x) => x.value == Settings.notificationType).text;
                          });
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // about
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Label(
                  Global.locale((s) => s.about, ctx: context),
                  type: LabelType.h3,
                ),
              ],
            ),
          ),
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
                    style: _buttonStyle(top: true),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Label(
                          Global.locale((s) => s.version, ctx: context),
                          type: LabelType.bodyRegular,
                          color: application.theme.fontColor1,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                        Label(
                          Global.versionFormat,
                          type: LabelType.bodyRegular,
                          color: application.theme.fontColor2,
                          height: 1,
                        ),
                      ],
                    ),
                    onPressed: () {},
                  ),
                ),
                Divider(height: 0, color: application.theme.dividerColor),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: TextButton(
                    style: _buttonStyle(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Label(
                          Global.locale((s) => s.contact_us, ctx: context),
                          type: LabelType.bodyRegular,
                          color: application.theme.fontColor1,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                        Row(
                          children: <Widget>[
                            Label(
                              'nmobile@nkn.org',
                              type: LabelType.bodyRegular,
                              color: application.theme.fontColor2,
                              height: 1,
                            ),
                          ],
                        ),
                      ],
                    ),
                    onPressed: () async {
                      launchUrl('mailto:nmobile@nkn.org');
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
                          Global.locale((s) => s.help, ctx: context),
                          type: LabelType.bodyRegular,
                          color: application.theme.fontColor1,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                        Row(
                          children: <Widget>[
                            Label(
                              'https://forum.nkn.org',
                              type: LabelType.bodyRegular,
                              color: application.theme.fontColor2,
                              height: 1,
                            ),
                          ],
                        ),
                      ],
                    ),
                    onPressed: () {
                      launchUrl('https://forum.nkn.org');
                    },
                  ),
                ),
              ],
            ),
          ),

          // advanced
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Label(
                  Global.locale((s) => s.advanced, ctx: context),
                  type: LabelType.h3,
                ),
              ],
            ),
          ),
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
                    style: _buttonStyle(top: true),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Label(
                          "订阅", // TODO:GG locale
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
                      Navigator.pushNamed(context, SettingsSubscribeScreen.routeName);
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
                          Global.locale((s) => s.cache, ctx: context),
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
                      Navigator.pushNamed(context, SettingsCacheScreen.routeName);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
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

  @override
  bool get wantKeepAlive => true;
}

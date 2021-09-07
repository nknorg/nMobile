import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/settings/settings_bloc.dart';
import 'package:nmobile/blocs/settings/settings_event.dart';
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
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/common/select.dart';
import 'package:nmobile/screens/settings/cache.dart';
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
    _initData();
    _currentLanguage = _getLanguageText(Settings.locale);
    _settingsBloc = BlocProvider.of<SettingsBloc>(context);
    _biometricsSelected = Settings.biometricsAuthentication;
  }

  _initData() {
    _languageList = <SelectListItem>[
      SelectListItem(
        text: S.of(Global.appContext).language_auto,
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
        text: S.of(Global.appContext).local_notification_only_name,
        value: NotificationType.only_name,
      ),
      SelectListItem(
        text: S.of(Global.appContext).local_notification_both_name_message,
        value: NotificationType.name_and_message,
      ),
      SelectListItem(
        text: S.of(Global.appContext).local_notification_none_display,
        value: NotificationType.none,
      ),
    ];
    _changeNotificationType();
  }

  String _getLanguageText(String lang) {
    if (lang == 'auto') {
      return S.of(Global.appContext).language_auto;
    }
    try {
      return _languageList.firstWhere((x) => x.value == lang).text;
    } catch (e) {
      return S.of(Global.appContext).language_auto;
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
    S _localizations = S.of(context);

    return Layout(
      headerColor: application.theme.primaryColor,
      header: Header(
        titleChild: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Label(
            _localizations.menu_settings,
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
                  _localizations.general,
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
                        SelectScreen.title: _localizations.change_language,
                        SelectScreen.selectedValue: Settings.locale,
                        SelectScreen.list: _languageList,
                      }).then((lang) {
                        if (lang != null) {
                          _settingsBloc?.add(UpdateLanguage(lang as String));
                          setState(() {
                            _currentLanguage = _getLanguageText(lang as String);
                          });
                        }
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Label(
                          _localizations.language,
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
                  _localizations.security,
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
                          _localizations.biometrics,
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
                                    ModalDialog.of(this.context).confirm(
                                      title: 'Wallet Info missing, Quit and ReImport', // TODO:GG locale wallet empty
                                      hasCloseButton: true,
                                    );
                                    return;
                                  }
                                  String? input = await BottomDialog.of(context).showInput(
                                    title: _localizations.verify_wallet_password,
                                    inputTip: _localizations.wallet_password,
                                    inputHint: _localizations.input_password,
                                    actionText: _localizations.continue_text,
                                    validator: Validator.of(context).password(),
                                    password: true,
                                  );
                                  if (!(await walletCommon.isPasswordRight(_wallet.address, input))) {
                                    Toast.show(S.of(context).tip_password_error);
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
                  _localizations.notification,
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
                          _localizations.notification_type,
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
                        SelectScreen.title: _localizations.local_notification,
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
                  _localizations.about,
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
                          _localizations.version,
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
                          _localizations.contact_us,
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
                    style: _buttonStyle(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Label(
                          _localizations.help,
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
                  _localizations.advanced,
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Label(
                          _localizations.cache,
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

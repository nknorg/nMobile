import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/push/device_token.dart';
import 'package:nmobile/common/push/remote_notification.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/util.dart';

class SettingsPushTokenDebugScreen extends BaseStateFulWidget {
  static const String routeName = '/settings/push_token_debug';

  @override
  _SettingsPushTokenDebugScreenState createState() => _SettingsPushTokenDebugScreenState();
}

class _SettingsPushTokenDebugScreenState extends BaseStateFulWidgetState<SettingsPushTokenDebugScreen> {
  String? _myToken;
  bool _loading = true;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    String? token = await DeviceToken.get();
    setState(() {
      _myToken = token;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.headBarColor2,
      header: Header(
        title: 'Push / Device Token',
        backgroundColor: application.theme.headBarColor2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _section(
              title: 'My Device Token',
              child: _loading
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Label(
                        'Loading...',
                        type: LabelType.bodyRegular,
                        color: application.theme.fontColor2,
                      ),
                    )
                  : _copyableBlock(
                      _myToken ?? '(empty)',
                      onCopy: () {
                        if (_myToken != null && _myToken!.isNotEmpty) {
                          Util.copyText(_myToken);
                          Toast.show(Settings.locale((s) => s.copy_success, ctx: context));
                        }
                      },
                    ),
            ),
            const SizedBox(height: 24),
            _section(
              title: 'Recently Sent Notifications',
              child: _recentList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: application.theme.backgroundLightColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(
            title,
            type: LabelType.bodyRegular,
            color: application.theme.fontColor1,
            fontWeight: FontWeight.bold,
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _copyableBlock(String text, {VoidCallback? onCopy}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SelectableText(
            text,
            style: TextStyle(
              fontSize: 12,
              color: application.theme.fontColor2,
              fontFamily: 'monospace',
            ),
          ),
        ),
        if (onCopy != null && text != '(empty)')
          IconButton(
            icon: Icon(Icons.content_copy, size: 20, color: application.theme.fontColor2),
            onPressed: onCopy,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
      ],
    );
  }

  Widget _recentList() {
    final list = RemoteNotification.recentSentNotifications;
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Label(
          'No recent sent notifications.',
          type: LabelType.bodyRegular,
          color: application.theme.fontColor2,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: list.asMap().entries.map((e) {
        final i = e.key;
        final item = e.value;
        final time = DateTime.fromMillisecondsSinceEpoch(item.at);
        final timeStr = '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        return Container(
          margin: EdgeInsets.only(bottom: i < list.length - 1 ? 12 : 0),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: application.theme.backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Label('NKN Address', type: LabelType.label, color: application.theme.fontColor2),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      item.nknAddress,
                      style: TextStyle(fontSize: 12, color: application.theme.fontColor1, fontFamily: 'monospace'),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.content_copy, size: 18, color: application.theme.fontColor2),
                    onPressed: () {
                      Util.copyText(item.nknAddress);
                      Toast.show(Settings.locale((s) => s.copy_success, ctx: context));
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Label('Token', type: LabelType.label, color: application.theme.fontColor2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SelectableText(
                      item.deviceToken,
                      style: TextStyle(fontSize: 11, color: application.theme.fontColor2, fontFamily: 'monospace'),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.content_copy, size: 18, color: application.theme.fontColor2),
                    onPressed: () {
                      Util.copyText(item.deviceToken);
                      Toast.show(Settings.locale((s) => s.copy_success, ctx: context));
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Label(timeStr, type: LabelType.label, color: application.theme.fontColor2),
            ],
          ),
        );
      }).toList(),
    );
  }
}

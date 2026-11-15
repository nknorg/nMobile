import 'package:flutter/material.dart';
import 'package:nkn_sdk_flutter/client.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/storages/settings.dart';

class SettingsCrossSendPolicyScreen extends BaseStateFulWidget {
  static const String routeName = '/settings/cross_send_policy';

  @override
  _SettingsCrossSendPolicyScreenState createState() => _SettingsCrossSendPolicyScreenState();
}

class _SettingsCrossSendPolicyScreenState extends BaseStateFulWidgetState<SettingsCrossSendPolicyScreen> {
  int _selectedPolicy = CrossSendPolicy.preferStable;
  List<SubClientConnectionState> _subClientStates = [];
  bool _loadingStates = false;

  static const List<int> _policyOptions = [
    CrossSendPolicy.none,
    CrossSendPolicy.anyConnected,
    CrossSendPolicy.allConnected,
    CrossSendPolicy.preferStable,
  ];

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var v = await SettingsStorage.getSettings(SettingsStorage.CROSS_SEND_POLICY);
    int value = CrossSendPolicy.preferStable;
    if (v != null) {
      if (v is int) {
        value = v;
      } else {
        value = int.tryParse(v.toString()) ?? CrossSendPolicy.preferStable;
      }
    }
    if (mounted) {
      setState(() {
        _selectedPolicy = value;
      });
    }
    _loadSubClientStates();
  }

  Future<void> _loadSubClientStates() async {
    if (_loadingStates || !mounted) return;
    setState(() {
      _loadingStates = true;
    });
    try {
      final list = await clientCommon.getSubClientConnectionStates();
      if (mounted) {
        setState(() {
          _subClientStates = list;
          _loadingStates = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _subClientStates = [];
          _loadingStates = false;
        });
      }
    }
  }

  static String _policyName(int policy) {
    switch (policy) {
      case CrossSendPolicy.none:
        return 'None';
      case CrossSendPolicy.anyConnected:
        return 'Any Connected';
      case CrossSendPolicy.allConnected:
        return 'All Connected';
      case CrossSendPolicy.preferStable:
        return 'Prefer Stable';
      default:
        return 'None';
    }
  }

  String _policyDesc(int policy) {
    switch (policy) {
      case CrossSendPolicy.none:
        return Settings.locale((s) => s.cross_send_policy_desc_none, ctx: context);
      case CrossSendPolicy.anyConnected:
        return Settings.locale((s) => s.cross_send_policy_desc_any_connected, ctx: context);
      case CrossSendPolicy.allConnected:
        return Settings.locale((s) => s.cross_send_policy_desc_all_connected, ctx: context);
      case CrossSendPolicy.preferStable:
        return Settings.locale((s) => s.cross_send_policy_desc_prefer_stable, ctx: context);
      default:
        return '';
    }
  }

  Future<void> _onPolicyChanged(int? policy) async {
    if (policy == null) return;
    await SettingsStorage.setSettings(SettingsStorage.CROSS_SEND_POLICY, policy);
    setState(() {
      _selectedPolicy = policy;
    });
    if (mounted) {
      Toast.show(Settings.locale((s) => s.cross_send_policy_restart_hint, ctx: context));
    }
  }

  String _connStateText(int state) {
    switch (state) {
      case ConnState.connecting:
        return Settings.locale((l) => l.conn_state_connecting, ctx: context);
      case ConnState.connected:
        return Settings.locale((l) => l.conn_state_connected, ctx: context);
      case ConnState.disconnected:
        return Settings.locale((l) => l.conn_state_disconnected, ctx: context);
      default:
        return Settings.locale((l) => l.conn_state_disconnected, ctx: context);
    }
  }

  static String _formatDuration(int totalSeconds) {
    if (totalSeconds < 60) return '${totalSeconds}s';
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    if (m < 60) return '${m}m ${s}s';
    final h = m ~/ 60;
    final mm = m % 60;
    return '${h}h ${mm}m ${s}s';
  }

  Widget _statChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: application.theme.fontColor2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: application.theme.fontColor1,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: application.theme.headBarColor2,
      header: Header(
        title: Settings.locale((s) => s.cross_send_policy, ctx: context),
        backgroundColor: application.theme.headBarColor2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: application.theme.backgroundLightColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Label(
                    Settings.locale((s) => s.cross_send_policy, ctx: context),
                    type: LabelType.bodyRegular,
                    color: application.theme.fontColor1,
                    fontWeight: FontWeight.bold,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _selectedPolicy,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: application.theme.backgroundColor,
                    ),
                    dropdownColor: application.theme.backgroundLightColor,
                    items: _policyOptions.map((p) {
                      return DropdownMenuItem<int>(
                        value: p,
                        child: Text(
                          _policyName(p),
                          style: TextStyle(
                            color: application.theme.fontColor1,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: _onPolicyChanged,
                  ),

                ],
              ),
            ),
            const SizedBox(height: 12),
            Label(
              _policyDesc(_selectedPolicy),
              type: LabelType.bodySmall,
              softWrap: true,
              color: application.theme.fontColor2,
              height: 1.3,
            ),
            const SizedBox(height: 12),
            Label(
              Settings.locale((s) => s.cross_send_policy_restart_tip, ctx: context),
              type: LabelType.bodySmall,
              softWrap: true,
              color: application.theme.fontColor2,
              height: 1.3,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: application.theme.backgroundLightColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Label(
                        Settings.locale((s) => s.cross_send_policy_sub_client_status, ctx: context),
                        type: LabelType.bodyRegular,
                        color: application.theme.fontColor1,
                        fontWeight: FontWeight.bold,
                      ),
                      TextButton(
                        onPressed: _loadingStates ? null : _loadSubClientStates,
                        child: Text(
                          Settings.locale((s) => s.cross_send_policy_sub_client_refresh, ctx: context),
                          style: TextStyle(
                            fontSize: 14,
                            color: application.theme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loadingStates)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Label(
                        '...',
                        type: LabelType.bodyRegular,
                        color: application.theme.fontColor2,
                      ),
                    )
                  else if (_subClientStates.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Label(
                        Settings.locale((s) => s.conn_state_not_connected, ctx: context),
                        type: LabelType.bodyRegular,
                        color: application.theme.fontColor2,
                      ),
                    )
                  else
                    ..._subClientStates.map((s) {
                      final isConnected = s.state == ConnState.connected;
                      final durationStr = s.connectionDurationSeconds > 0
                          ? _formatDuration(s.connectionDurationSeconds)
                          : Settings.locale((l) => l.subclient_duration_na, ctx: context);
                      final scoreStr = s.state == ConnState.connected
                          ? s.stabilityScore.toStringAsFixed(2)
                          : '—';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: application.theme.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Label(
                                  'Sub-client ${s.index}',
                                  type: LabelType.bodyRegular,
                                  color: application.theme.fontColor1,
                                  fontWeight: FontWeight.w600,
                                ),
                                const SizedBox(width: 8),
                                Label(
                                  _connStateText(s.state),
                                  type: LabelType.label,
                                  color: isConnected
                                      ? application.theme.primaryColor
                                      : application.theme.fontColor2,
                                  fontWeight: isConnected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                _statChip(
                                  Settings.locale((l) => l.subclient_conn_duration, ctx: context),
                                  durationStr,
                                ),
                                _statChip(
                                  Settings.locale((l) => l.subclient_reconnect_count, ctx: context),
                                  '${s.reconnectCount}',
                                ),
                                _statChip(
                                  Settings.locale((l) => l.subclient_send_failure_count, ctx: context),
                                  '${s.sendFailureCount}',
                                ),
                                _statChip(
                                  Settings.locale((l) => l.subclient_score, ctx: context),
                                  scoreStr,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

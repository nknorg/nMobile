import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/api.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/schemas/cdn_miner.dart';
import 'package:nmobile/schemas/chat.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/topic.dart';
import 'package:nmobile/screens/chat/channel.dart';
import 'package:nmobile/screens/ncdn/with_draw_page.dart';
import 'package:nmobile/screens/view/dialog_alert.dart';
import 'package:oktoast/oktoast.dart';

import 'node_main_page.dart';

class NcdnHomeScreen extends StatefulWidget {
  static const String routeName = '/ncdn/home';

  NcdnHomeScreen({Key key}) : super(key: key);

  @override
  _NcdnHomeScreenState createState() => _NcdnHomeScreenState();
}

class _NcdnHomeScreenState extends State<NcdnHomeScreen> {
  Api _api;

  TextEditingController _balanceController = TextEditingController(text: '- USDT');
  double _balance;
  TextEditingController _prevWeekIncomeBalanceController = TextEditingController(text: '- USDT');
  TextEditingController _referrerBalanceController = TextEditingController(text: '- USDT');
  TextEditingController _incomeBalanceController = TextEditingController(text: '- USDT');
  TextEditingController _dailyEstimateController = TextEditingController(text: '- USDT');
  TextEditingController _weeklyEstimateController = TextEditingController(text: '- USDT');

  ChatBloc _chatBloc;

  initAsync() async {
    _api = Api(mySecretKey: hexDecode(Global.minerData.se), myPublicKey: hexDecode(Global.minerData.pub), otherPubkey: hexDecode(Global.SERVER_PUBKEY));
    String url = Api.CDN_MINER_DB + '/api/v1/sum/${Global.minerData.pub}';
    var params = {
      'where': {},
      'sum': 'amount',
    };
    _api.post(url, params, isEncrypted: true).then((res) {
      if (res != null && res.length > 0) {
        var data = res[0]['total'];
        _balance = data;
        _balanceController.text = Format.currencyFormat(data, decimalDigits: 3) + ' USDT';
      } else {
        _balanceController.text = Format.currencyFormat(0, decimalDigits: 3) + ' USDT';
      }
    });
    _api
        .post(
            Api.CDN_MINER_DB + '/api/v1/sum/${Global.minerData.pub}',
            {
              'where': {
                'token_type': 'usdt',
                'is_out': false,
              },
              'sum': 'amount',
            },
            isEncrypted: true)
        .then((res) {
      if (res != null && res.length > 0) {
        var data = res[0]['total'];
        _incomeBalanceController.text = Format.currencyFormat(data, decimalDigits: 3) + ' USDT';
      } else {
        _incomeBalanceController.text = Format.currencyFormat(0, decimalDigits: 3) + ' USDT';
      }
    });

    _api.get(Api.CDN_MINER_API + '/api/v3/referral_income/${Global.minerData.pub}').then((res) {
      var data = res;
      if (data != null && data['success']) {
        _referrerBalanceController.text = Format.currencyFormat(data['result'], decimalDigits: 3) + ' USDT';
      }
    });
    _api.get(Api.CDN_MINER_API + '/api/v3/daily_estimate/${Global.minerData.pub}').then((res) {
      var data = res;
      if (data != null && data['success']) {
        _dailyEstimateController.text = Format.currencyFormat(data['result'], decimalDigits: 3) + ' USDT';
      }
    });
    _api.get(Api.CDN_MINER_API + '/api/v3/weekly_estimate/${Global.minerData.pub}').then((res) {
      var data = res;
      if (data != null && data['success']) {
        _weeklyEstimateController.text = Format.currencyFormat(data['result'], decimalDigits: 3) + ' USDT';
      }
    });

    DateTime now = new DateTime.now();
    int weekday = now.weekday;
    var monday = getTimestampLatest(true, -weekday + 1 + -1 * 7);
    var sunday = getTimestampLatest(true, 7 - weekday + 1 - 1 * 7);
    _api
        .post(
            Api.CDN_MINER_DB + '/api/v1/sum/${Global.minerData.pub}',
            {
              'where': {
                'token_type': 'usdt',
                'is_out': false,
                'time': {'\$gt': monday ~/ 1000, '\$lte': sunday ~/ 1000}
              },
              'sum': 'amount',
            },
            isEncrypted: true)
        .then((res) {
      if (res != null && res.length > 0) {
        var data = res[0]['total'];
        _prevWeekIncomeBalanceController.text = Format.currencyFormat(data, decimalDigits: 3) + ' USDT';
      } else {
        _prevWeekIncomeBalanceController.text = Format.currencyFormat(0, decimalDigits: 3) + ' USDT';
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _chatBloc = BlocProvider.of<ChatBloc>(context);
    initAsync();
    CdnMiner.removeCacheData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        title: '挖矿收益',
        backgroundColor: DefaultTheme.backgroundColor4,
        action: FlatButton(
          child: Label(
            '提现',
            color: Colors.white,
          ),
          onPressed: () {
            showTip();
          },
        ),
      ),
      body: Builder(
        builder: (BuildContext context) => BodyBox(
          padding: const EdgeInsets.only(top: 2, left: 20, right: 20),
          color: DefaultTheme.backgroundLightColor,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Flex(
                direction: Axis.vertical,
                children: <Widget>[
                  Expanded(
                    flex: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Label(
                                '昨日预估收益',
                                type: LabelType.h4,
                                textAlign: TextAlign.start,
                              ),
                            ],
                          ),
                          Textbox(
                            controller: _dailyEstimateController,
                            readOnly: true,
                            enabled: false,
                            textInputAction: TextInputAction.next,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Label(
                                '本周预估收益',
                                type: LabelType.h4,
                                textAlign: TextAlign.start,
                              ),
                            ],
                          ),
                          Textbox(
                            controller: _weeklyEstimateController,
                            readOnly: true,
                            enabled: false,
                            textInputAction: TextInputAction.next,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Label(
                                '上周收益',
                                type: LabelType.h4,
                                textAlign: TextAlign.start,
                              ),
                            ],
                          ),
                          Textbox(
                            controller: _prevWeekIncomeBalanceController,
                            readOnly: true,
                            enabled: false,
                            textInputAction: TextInputAction.next,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Label(
                                '历史总收益',
                                type: LabelType.h4,
                                textAlign: TextAlign.start,
                              ),
                            ],
                          ),
                          Textbox(
                            controller: _incomeBalanceController,
                            readOnly: true,
                            enabled: false,
                            textInputAction: TextInputAction.next,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Label(
                                '当前可提现收益',
                                type: LabelType.h4,
                                textAlign: TextAlign.start,
                              ),
                            ],
                          ),
                          Textbox(
                            controller: _balanceController,
                            readOnly: true,
                            enabled: false,
                            textInputAction: TextInputAction.next,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Label(
                                '推荐收益',
                                type: LabelType.h4,
                                textAlign: TextAlign.start,
                              ),
                            ],
                          ),
                          Textbox(
                            controller: _referrerBalanceController,
                            readOnly: true,
                            enabled: false,
                            textInputAction: TextInputAction.next,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Button(
                              width: double.infinity,
                              text: '查看节点',
                              onPressed: () {
                                Navigator.of(context).pushNamed(NodeMainPage.routeName);
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Button(
                              width: double.infinity,
                              text: '获取邀请码',
                              onPressed: () async {
                                if (Global.currentClient == null) {
                                  showToast('请先连接D-Chat');
                                  return;
                                }

                                String topic = 'nCDN-support.58ecacbab587527326dd449329ca60ccad4d6f08331afde9987de120367e1f45';
                                String type = TopicType.private;
                                String owner = getOwnerPubkeyByTopic(topic);
                                LoadingDialog.of(context).show();
                                var duration = 400000;
                                var hash = await TopicSchema.subscribe(topic: topic, duration: duration);
                                if (hash != null) {
                                  var sendMsg = MessageSchema.fromSendData(
                                    from: Global.currentClient.address,
                                    topic: topic,
                                    contentType: ContentType.dchatSubscribe,
                                  );
                                  sendMsg.isOutbound = true;
                                  sendMsg.content = sendMsg.toDchatSubscribeData();
                                  _chatBloc.add(SendMessage(sendMsg));

                                  DateTime now = DateTime.now();
                                  var topicSchema = TopicSchema(topic: topic, type: type, owner: owner, expiresAt: now.add(blockToExpiresTime(duration)));
                                  if (type == TopicType.private) {
                                    await topicSchema.acceptPrivateMember(addr: Global.currentClient.publicKey);
                                  }

                                  await topicSchema.insertOrUpdate();
                                  topicSchema = await TopicSchema.getTopic(topic);
                                  LoadingDialog.of(context).close();
                                  Navigator.of(context).pushNamed(ChatGroupPage.routeName, arguments: ChatSchema(type: ChatType.PrivateChannel, topic: topicSchema));
                                }
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
          ),
        ),
      ),
    );
  }

  showTip() {
    if (_balance == null || _balance < 1) {
      SimpleAlert(context: context, content: '最小提现收益需大于1USDT').show();
    } else {
      Navigator.pushNamed(context, WithDrawPage.routeName, arguments: {
        "maxBalance": _balance,
      }).then((v) {
        initAsync();
      });
    }
  }
}

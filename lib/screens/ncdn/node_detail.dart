import 'package:common_utils/common_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/api.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/schemas/wallet.dart';

class NodeDetailData {
  String nknId;
  num flow;
  num cost;
  num contribution;

  NodeDetailData({this.nknId, this.flow, this.cost, this.contribution});
}

class NodeDetailScreen extends StatefulWidget {
  static const String routeName = '/ncdn/node/detail';

  final Map arguments;

  NodeDetailScreen({Key key, this.arguments}) : super(key: key);

  @override
  _NodeDetailScreenState createState() => _NodeDetailScreenState();
}

class _NodeDetailScreenState extends State<NodeDetailScreen> {
  final String SERVER_PUBKEY = 'eb08c2a27cb61fe414654a1e9875113d715737247addf01db06ea66cafe0b5c8';
  WalletSchema _wallet;
  String _publicKey;
  String _seed;
  Api _api;
  DateTime _start;
  DateTime _end;
  TextEditingController _startController = TextEditingController();
  TextEditingController _endController = TextEditingController();
  List<NodeDetailData> _list = <NodeDetailData>[];
  double _sumBalance;

  initAsync() async {
    _api = Api(mySecretKey: hexDecode(_seed), myPublicKey: hexDecode(_publicKey), otherPubkey: hexDecode(SERVER_PUBKEY));
    search();
  }

  @override
  void initState() {
    super.initState();
    _wallet = widget.arguments['wallet'];
    _publicKey = widget.arguments['publicKey'];
    _seed = widget.arguments['seed'];

    Future.delayed(Duration(milliseconds: 500), () {
      _start = getStartOfDay(DateTime.now().add(Duration(days: -2)));
      _end = getStartOfDay(DateTime.now().add(Duration(days: -1)));
      _startController.text = DateUtil.formatDate(_start, format: 'yyyy-MM-dd');
      _endController.text = DateUtil.formatDate(_end, format: 'yyyy-MM-dd');
      initAsync();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  search() {
    LoadingDialog.of(context).show();
    _api
        .post(
            'http://39.100.108.44:6443/api/v2/quantity_flow/${_wallet.address}',
            {
              'start': _start.millisecondsSinceEpoch ~/ 1000,
              'end': _end.add(Duration(days: 1)).millisecondsSinceEpoch ~/ 1000,
            },
            isEncrypted: true)
        .then((res) {
      Map<String, dynamic> data = (res as Map);
      if (res != null && data.keys.length > 0) {
        _sumBalance = 0;
        _list = <NodeDetailData>[];
        for (String key in data.keys) {
          List<dynamic> val = (data[key] as List<dynamic>);
          _sumBalance += val[1];
          _list.add(NodeDetailData(nknId: key, flow: val[0], cost: val[1], contribution: val[2]));
        }
        setState(() {});
      }
      LoadingDialog.of(context).close();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        title: '节点明细',
        backgroundColor: DefaultTheme.backgroundColor4,
      ),
      body: Builder(
        builder: (BuildContext context) => BodyBox(
          padding: const EdgeInsets.only(top: 2, left: 20, right: 20),
          color: DefaultTheme.backgroundLightColor,
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              children: <Widget>[
                Container(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Label(
                              '开始时间',
                              type: LabelType.h4,
                              textAlign: TextAlign.start,
                            ),
                            Textbox(
                              controller: _startController,
                              readOnly: true,
                              onTap: () async {
                                DateTime date = await showDatePicker(
                                  context: context,
                                  initialDate: _start,
                                  firstDate: DateTime(2020, 1),
                                  lastDate: getEndOfDay(DateTime.now().add(Duration(days: -1))),
                                );
                                if (date != null) {
                                  _start = date;
                                }
                                _startController.text = DateUtil.formatDate(_start, format: 'yyyy-MM-dd');
                              },
                              prefixIcon: GestureDetector(
                                child: Container(
                                  width: 20,
                                  child: Icon(
                                    FontAwesomeIcons.calculator,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Label(
                              '结束时间',
                              type: LabelType.h4,
                              textAlign: TextAlign.start,
                            ),
                            Textbox(
                              controller: _endController,
                              readOnly: true,
                              onTap: () async {
                                DateTime date = await showDatePicker(
                                  context: context,
                                  initialDate: _end,
                                  firstDate: DateTime(2020, 1),
                                  lastDate: getEndOfDay(DateTime.now().add(Duration(days: -1))),
                                );
                                if (date != null) {
                                  _end = date;
                                }
                                _endController.text = DateUtil.formatDate(_end, format: 'yyyy-MM-dd');
                              },
                              prefixIcon: GestureDetector(
                                child: Container(
                                  width: 20,
                                  child: Icon(
                                    FontAwesomeIcons.calculator,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: Flex(
                    direction: Axis.vertical,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Spacer(),
                          Button(
                            text: '搜索',
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              search();
                            },
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                          Label(
                            '当前总收益: ',
                            type: LabelType.h4,
                            textAlign: TextAlign.start,
                          ),
                          Label(
                            (_sumBalance != null ? Format.currencyFormat(_sumBalance, decimalDigits: 3) : '-') + ' USDT',
                            type: LabelType.h4,
                            color: DefaultTheme.fontColor1,
                          )
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: EdgeInsets.only(top: 6.h),
                    child: ListView.separated(
                      itemCount: _list.length,
                      padding: EdgeInsets.only(bottom: 30.h),
                      itemBuilder: (BuildContext context, int index) {
                        NodeDetailData node = _list[index];
                        return Container(
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: DefaultTheme.line, width: 0.2.w))),
                          child: Column(
                            children: <Widget>[
                              Label(
                                'NKN ID: ${node.nknId}',
                                color: DefaultTheme.fontColor1,
                                type: LabelType.bodyRegular,
                                softWrap: true,
                              ),
                              SizedBox(height: 6.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Label(
                                    '收益: ${node.cost != null ? Format.currencyFormat(node.cost, decimalDigits: 3) : '-'} USDT',
                                    color: DefaultTheme.fontColor1,
                                    type: LabelType.bodyRegular,
                                    softWrap: true,
                                  ),
                                  Label(
                                    '流量: ${node.flow != null ? getFormatSize(node.flow.toDouble(), unitArr: ['Bytes', 'KBytes', 'MBytes', 'GBytes', 'TBytes']) : '-'}',
                                    color: DefaultTheme.fontColor1,
                                    type: LabelType.bodyRegular,
                                    softWrap: true,
                                  )
//                                  InkWell(
//                                    child: Label(
//                                      '查看详情',
//                                      color: DefaultTheme.primaryColor,
//                                      type: LabelType.bodyRegular,
//                                    ),
//                                    onTap: () {
//                                      ModalDialog.of(context).show(
//                                        height: 300,
//                                        title: Label(
//                                          '节点明细',
//                                          type: LabelType.h2,
//                                          softWrap: true,
//                                        ),
//                                        content: Container(
//                                          child: Column(
//                                            crossAxisAlignment: CrossAxisAlignment.start,
//                                            children: <Widget>[
//                                              Label(
//                                                'NKN ID: ${node.nknId}',
//                                                color: DefaultTheme.fontColor1,
//                                                type: LabelType.bodyRegular,
//                                                softWrap: true,
//                                              ),
//                                              Label(
//                                                '收益: ${node.cost != null ? Format.currencyFormat(node.cost, decimalDigits: 3) : '-'} USDT',
//                                                type: LabelType.h4,
//                                                color: DefaultTheme.fontColor1,
//                                                softWrap: true,
//                                              ),
//                                              Label(
//                                                '流量: ${node.flow != null ? getFormatSize(node.flow.toDouble(), unitArr: ['Bytes', 'KBytes', 'MBytes', 'GBytes', 'TBytes']) : '-'}',
//                                                type: LabelType.h4,
//                                                color: DefaultTheme.fontColor1,
//                                                softWrap: true,
//                                              ),
//                                            ],
//                                          ),
//                                        ),
//                                      );
//                                    },
//                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      separatorBuilder: (BuildContext context, int index) {
                        return Divider(
                          height: 1,
                          color: DefaultTheme.backgroundColor2,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  getFormatSize(double value, {unitArr = const ['B', 'KB', 'MB', 'GB', 'TB']}) {
    if (null == value) {
      return '0 Bytes';
    }
    int index = 0;
    while (value > 1024) {
      if (index == unitArr.length - 1) {
        break;
      }
      index++;
      value = value / 1024;
    }
    String size = value.toStringAsFixed(2);
    return '$size ${unitArr[index]}';
  }
}

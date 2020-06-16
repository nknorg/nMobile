import 'dart:async';

import 'package:common_utils/common_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:nmobile/blocs/cdn/cdn_bloc.dart';
import 'package:nmobile/blocs/cdn/cdn_state.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/api.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/schemas/cdn_miner.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/ncdn/node_detail_page.dart';
import 'package:nmobile/screens/ncdn/node_list_page.dart';
import 'package:nmobile/screens/scanner.dart';
import 'package:oktoast/oktoast.dart';

class NodeMainPage extends StatefulWidget {
  static const String routeName = '/ncdn/node/detail';

  final Map arguments;

  NodeMainPage({Key key, this.arguments}) : super(key: key);

  @override
  _NodeMainPageState createState() => _NodeMainPageState();
}

class _NodeMainPageState extends State<NodeMainPage> {
  final String SERVER_PUBKEY = 'eb08c2a27cb61fe414654a1e9875113d715737247addf01db06ea66cafe0b5c8';
  WalletSchema _wallet;
  String _publicKey;
  String _seed;
  Api _api;
  DateTime _start;
  DateTime _end;

  String _startText = '';
  String _endText = '';

  List<CdnMiner> _list = <CdnMiner>[];
  double _sumBalance;
  CDNBloc _cdnBloc;
  Map<String, dynamic> responseData;
  StreamSubscription _subscription;

  initAsync() async {
    await CdnMiner.removeCacheData();
    var listTemp = await CdnMiner.getAllCdnMiner();
    if (mounted) {
      setState(() {
        _list = listTemp;
      });
    }

    _api = Api(mySecretKey: hexDecode(_seed), myPublicKey: hexDecode(_publicKey), otherPubkey: hexDecode(SERVER_PUBKEY));
    search();
  }

  @override
  void initState() {
    super.initState();
    _wallet = widget.arguments['wallet'];
    _publicKey = widget.arguments['publicKey'];
    _seed = widget.arguments['seed'];
    _start = getStartOfDay(DateTime.now().add(Duration(days: -1)));
    _end = getStartOfDay(DateTime.now().add(Duration(days: -1)));
    _startText = DateUtil.formatDate(_start, format: 'yyyy-MM-dd');
    _endText = DateUtil.formatDate(_end, format: 'yyyy-MM-dd');
    _cdnBloc = BlocProvider.of<CDNBloc>(context);
    _subscription = _cdnBloc.listen((state) async {
      if (state is LoadSate) {
        LogUtil.v('======initState=====');
        var tempList = await CdnMiner.getAllCdnMiner();
        if (mounted) {
          setState(() {
            _list = tempList;
          });
        }

        await resetFormatData();
      }
    });

    Future.delayed(Duration(milliseconds: 500), () {
      initAsync();
    });
  }

  @override
  void dispose() {
//    _cdnBloc.close();
    _subscription.cancel();
    super.dispose();
  }

  search() {
//    LoadingDialog.of(context).show();
//    String url = 'http://39.100.108.44:6443/api/v2/quantity_flow/NKNGVRacskwuKRzwVoNmJdjWS7mqB5VKAzju';
    String url = 'http://39.100.108.44:6443/api/v2/quantity_flow/${_wallet.address}';
    var params = {
      'start': _start.millisecondsSinceEpoch ~/ 1000,
      'end': _end.add(Duration(days: 1)).millisecondsSinceEpoch ~/ 1000,
    };
    _api.post(url, params, isEncrypted: true).then((res) async {
      responseData = (res as Map);
      if (res != null) {
        var tempList = await CdnMiner.getAllCdnMiner();
        if (mounted) {
          setState(() {
            _list = tempList;
          });
        }
        resetFormatData();
        for (CdnMiner cdn in _list) {
          cdn.getMinerDetail();
        }
      }
//      LoadingDialog.of(context).close();
    });
  }

  resetFormatData() async {
    double totalAmount = 0;
    if (responseData != null && responseData.keys != null) {
      for (String key in responseData.keys) {
        List<dynamic> val = (responseData[key] as List<dynamic>);
        totalAmount += val[1];
        var cdn = _list.firstWhere((x) => x.nshId == key, orElse: () => null);
        if (cdn == null) {
          cdn = CdnMiner(key, flow: val[0], cost: val[1], contribution: val[2]);
          var b = await cdn.insertOrUpdate();
          if (b) {
            _list.add(cdn);
          }
        } else {
          int i = _list.indexOf(cdn);
          _list[i].flow = val[0];
          _list[i].cost = val[1];
          _list[i].contribution = val[2];
        }
      }
    }

    if (mounted) {
      setState(() {
        _sumBalance = totalAmount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        title: '节点明细',
        backgroundColor: DefaultTheme.backgroundColor4,
        action: Button(
          padding: EdgeInsets.zero,
          icon: true,
          child: Label(
            '添加',
            color: Colors.white,
          ),
          onPressed: () {
            addAction();
          },
        ),
      ),
      body: Builder(
        builder: (BuildContext context) => BodyBox(
          padding: EdgeInsets.only(top: 2, left: 16.w, right: 16.w),
          color: DefaultTheme.backgroundColor6,
          child: Padding(
            padding: EdgeInsets.only(top: 20.h),
            child: Column(
              children: <Widget>[
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    children: <Widget>[
                      SizedBox(height: 6.h),
                      Row(
                        children: <Widget>[
                          Label(
                            '设备总数',
                            color: DefaultTheme.fontColor1,
                            type: LabelType.bodyRegular,
                            softWrap: true,
                          ),
                          Spacer(),
                          Label(
                            responseData == null ? '获取中...' : _list.length.toString(),
                            color: DefaultTheme.fontColor1,
                            type: LabelType.bodyRegular,
                            softWrap: true,
                          )
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Row(
                        children: <Widget>[
                          Label(
                            '运行中',
                            color: DefaultTheme.fontColor1,
                            type: LabelType.bodyRegular,
                            softWrap: true,
                          ),
                          Spacer(),
                          Label(
                            responseData == null
                                ? '获取中...'
                                : _list
                                    .where((item) {
                                      return item.getStatus() == '运行中';
                                    })
                                    .toList()
                                    .length
                                    .toString(),
                            color: DefaultTheme.fontColor1,
                            type: LabelType.bodyRegular,
                            softWrap: true,
                          )
                        ],
                      ),
                      SizedBox(height: 10.h),
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, NodeListPage.routeName,
                              arguments: _list.where((item) {
                                return item.getStatus() == '故障';
                              }).toList());
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Label(
                              '故障数量',
                              color: DefaultTheme.fontColor1,
                              type: LabelType.bodyRegular,
                              softWrap: true,
                            ),
                            Spacer(),
                            Label(
                              responseData == null
                                  ? '获取中...'
                                  : _list
                                      .where((item) {
                                        return item.getStatus() == '故障';
                                      })
                                      .toList()
                                      .length
                                      .toString(),
                              color: DefaultTheme.fontColor1,
                              type: LabelType.bodyRegular,
                              softWrap: true,
                            ),
                            SvgPicture.asset(
                              'assets/icons/right.svg',
                              width: 24,
                              color: DefaultTheme.fontColor2,
                            )
                          ],
                        ),
                      ),
                      SizedBox(height: 10.h),
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, NodeListPage.routeName,
                              arguments: _list.where((item) {
                                return item.getStatus() == '未知';
                              }).toList());
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Label(
                              '未知数量',
                              color: DefaultTheme.fontColor1,
                              type: LabelType.bodyRegular,
                              softWrap: true,
                            ),
                            Spacer(),
                            Label(
                              responseData == null
                                  ? '获取中...'
                                  : _list
                                      .where((item) {
                                        return item.getStatus() == '未知';
                                      })
                                      .toList()
                                      .length
                                      .toString(),
                              color: DefaultTheme.fontColor1,
                              type: LabelType.bodyRegular,
                              softWrap: true,
                            ),
                            SvgPicture.asset(
                              'assets/icons/right.svg',
                              width: 24,
                              color: DefaultTheme.fontColor2,
                            )
                          ],
                        ),
                      ),
                      SizedBox(height: 10.h),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),
                Container(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      InkWell(
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
                          if (mounted) {
                            setState(() {
                              _startText = DateUtil.formatDate(_start, format: 'yyyy-MM-dd');
                            });
                          }
                        },
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                            ),
                            SizedBox(width: 5.w),
                            Label(
                              _startText + " 00:00",
                              color: DefaultTheme.fontColor1,
                              type: LabelType.bodyRegular,
                              softWrap: true,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Label(
                        '至',
                        color: DefaultTheme.fontColor1,
                        type: LabelType.bodyRegular,
                        softWrap: true,
                      ),
                      SizedBox(width: 10.w),
                      InkWell(
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
                          setState(() {
                            _endText = DateUtil.formatDate(_end, format: 'yyyy-MM-dd');
                          });
                        },
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                            ),
                            SizedBox(width: 5.w),
                            Label(
                              _endText + " 23:59",
                              color: DefaultTheme.fontColor1,
                              type: LabelType.bodyRegular,
                              softWrap: true,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10.w),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),
                Row(
                  children: <Widget>[
                    Spacer(),
                    InkWell(
                      onTap: () {
                        search();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 14.w),
                        decoration: BoxDecoration(color: DefaultTheme.primaryColor, borderRadius: BorderRadius.circular(100)),
                        child: Label(
                          '搜索',
                          color: Colors.white,
                          type: LabelType.bodyRegular,
                          softWrap: true,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    Label(
                      '总收益: ',
                      type: LabelType.h4,
                      textAlign: TextAlign.start,
                    ),
                    Label(
                      (_sumBalance != null ? Format.currencyFormat(_sumBalance, decimalDigits: 3) : '-') + ' USDT',
                      type: LabelType.h4,
                    )
                  ],
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: EdgeInsets.only(top: 6.h),
                    child: ListView.builder(
                      itemCount: _list.length,
                      padding: EdgeInsets.only(bottom: 30.h),
                      itemBuilder: (BuildContext context, int index) {
                        CdnMiner node = _list[index];
                        return Container(
                          padding: EdgeInsets.all(12.w),
                          margin: EdgeInsets.only(top: 10.h),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                          child: InkWell(
                            onTap: () {
                              Navigator.pushNamed(context, NodeDetailPage.routeName, arguments: node);
                            },
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Label(
                                            '名称: ${node.name}',
                                            color: DefaultTheme.fontColor1,
                                            type: LabelType.bodyRegular,
                                            softWrap: true,
                                          ),
                                          Spacer(),
                                          Label(
                                            '状态: ${node.getStatus()}',
                                            color: DefaultTheme.fontColor1,
                                            type: LabelType.bodyRegular,
                                            softWrap: true,
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 6.h),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: <Widget>[
                                          Label(
                                            '预估收益: ${node.cost != null ? Format.currencyFormat(node.cost, decimalDigits: 3) : '-'} USDT',
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
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                SvgPicture.asset(
                                  'assets/icons/right.svg',
                                  width: 24,
                                  color: DefaultTheme.fontColor2,
                                )
                              ],
                            ),
                          ),
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

//  TextEditingController _nShellIdController = TextEditingController();
//  GlobalKey _notesFormKey = new GlobalKey<FormState>();

  addAction() async {
    var qrData = await Navigator.of(context).pushNamed(ScannerScreen.routeName);
    if (qrData != null && qrData.toString().length >= 60) {
      LogUtil.v(_list);
      var result = _list.firstWhere((v) => v.nshId == qrData, orElse: () => null);
      if (result == null) {
        result = CdnMiner(qrData);
        result.insertOrUpdate().then((v) {
          if (v) {
            setState(() {
              _list.add(result);
            });
          }
        });
        showToast('添加成功');
      } else {
        showToast('已存在');
      }
    } else {
      showToast('请输入正确的ID');
    }
  }
}

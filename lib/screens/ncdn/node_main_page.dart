import 'dart:async';

import 'package:common_utils/common_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyrefresh/easy_refresh.dart';
import 'package:flutter_easyrefresh/material_header.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:nmobile/blocs/cdn/cdn_bloc.dart';
import 'package:nmobile/blocs/cdn/cdn_state.dart';
import 'package:nmobile/components/box/body.dart';
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
import 'package:nmobile/screens/view/ncdn_main_header.dart';
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
  EasyRefreshController _controller;

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
    _controller = EasyRefreshController();
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
        if (mounted) {
          setState(() {
            var cdn = _list.firstWhere((x) => x.nshId == state.data.nshId, orElse: () => null);
            if (cdn != null) {
              var index = _list.indexOf(cdn);
              if (index != -1) {
                _list[index].data = state.data.data;
              }
            }
          });
        }
//        await resetFormatData();
      }
    });

    Future.delayed(Duration(milliseconds: 500), () {
      initAsync();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  search() {
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
        resultData = await getRequestListData();
        await mergeAction();
        //循环获取设备详情
        for (CdnMiner cdn in _list) {
          cdn.getMinerDetail();
        }
      }
    });
  }

  //合并数据库数据
  mergeAction() async {
    for (var n in resultData) {
      var cdn = _list.firstWhere((x) => x.nshId == n.nshId, orElse: () => null);
      if (cdn == null) {
        cdn = CdnMiner(n.nshId, flow: n.flow, cost: n.cost, contribution: n.contribution);
        await cdn.insertOrUpdate();
        _list.add(cdn);
      } else {
        int i = _list.indexOf(cdn);
        _list[i].flow = n.flow;
        _list[i].cost = n.cost;
        _list[i].contribution = n.contribution;
      }
    }
    setState(() {});
  }

  List<CdnMiner> resultData = [];

  //获取流量收益数据
  getRequestListData() async {
    resultData.clear();
    double amount = 0;
    if (responseData != null && responseData.keys != null) {
      LogUtil.v(responseData.keys);
      LogUtil.v('===========');
      for (String key in responseData.keys) {
        if (key != null && key.length > 0) {
          List<dynamic> val = (responseData[key] as List<dynamic>);
          LogUtil.v(val);
          amount += val[1];
          resultData.add(CdnMiner(key, flow: val[0], cost: val[1], contribution: val[2]));
        }
      }
    }
    setState(() {
      _sumBalance = amount;
    });
    return resultData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: NcdnMainPage.getHeader(context, () {
        addAction();
      }),
      body: Builder(
        builder: (BuildContext context) => BodyBox(
          padding: EdgeInsets.only(top: 2, left: 16.w, right: 16.w),
          color: DefaultTheme.backgroundColor6,
          child: EasyRefresh(
            controller: _controller,
            header: MaterialHeader(),
            onRefresh: () async {
              search();
            },
            child: Container(
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
                        ),
                        Spacer(),
                        InkWell(
                          onTap: () {
                            filterAction();
                          },
                          child: Row(
                            children: <Widget>[
                              Label(
                                '排序',
                                type: LabelType.h4,
                                color: DefaultTheme.fontColor2,
                                textAlign: TextAlign.start,
                              ),
                              Icon(Icons.keyboard_arrow_down, color: DefaultTheme.fontColor2)
                            ],
                          ),
                        )
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 6.h),
                      child: ListView.builder(
                        itemCount: _list.length,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
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
                  ],
                ),
              ),
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

  Widget _getPopItemView(text, {color = 0xFF2A2A3C}) {
    return Container(
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(color), fontSize: 16.sp),
        ),
      ),
      width: double.infinity,
      height: 50.h,
      color: Colors.white,
    );
  }

  filterAction() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return new Container(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Label(
                      '请选择排序方式',
                      color: DefaultTheme.fontColor1,
                      type: LabelType.bodyRegular,
                      softWrap: true,
                    ),
                  ),
                  Spacer()
                ],
              ),
              InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    getFilterName();
                  },
                  child: _getPopItemView('名称')),
              InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _list.sort((left, right) => (right.cost ?? 0).compareTo((left.cost ?? 0)));
                    });
                  },
                  child: _getPopItemView('收益')),
              InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _list.sort((left, right) => (right.flow ?? 0).compareTo((left.flow ?? 0)));
                    });
                  },
                  child: _getPopItemView('流量')),
              InkWell(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: _getPopItemView('取消')),
            ],
          ),
        );
      },
    ).then((val) {
      print(val);
    });
  }

  getFilterName() {
    try {
      List<CdnMiner> numbers = [];
      List<CdnMiner> texts = [];
      for (CdnMiner m in _list) {
        try {
          num.parse(m.name);
          numbers.add(m);
        } catch (e) {
          texts.add(m);
        }
      }
      numbers.sort((a, b) => (num.parse(a.name).compareTo(num.parse(b.name))));
      texts.sort((a, b) => (a.name.codeUnitAt(0) > b.name.codeUnitAt(0) ? 1 : 0));

      numbers.addAll(texts);
      if (numbers.length == _list.length) {
        setState(() {
          _list = numbers;
        });
      }
    } catch (e) {
      LogUtil.v(e);
    }
  }
}

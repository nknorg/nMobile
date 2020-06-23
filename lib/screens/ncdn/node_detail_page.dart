import 'dart:async';
import 'dart:convert';

import 'package:common_utils/common_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:nmobile/blocs/cdn/cdn_bloc.dart';
import 'package:nmobile/blocs/cdn/cdn_event.dart';
import 'package:nmobile/blocs/cdn/cdn_state.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/api.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/schemas/cdn_miner.dart';
import 'package:nmobile/utils/copy_utils.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:oktoast/oktoast.dart';

class NodeDetailPage extends StatefulWidget {
  static final String routeName = "NodeDetailPage";
  final CdnMiner arguments;

  const NodeDetailPage({Key key, this.arguments}) : super(key: key);

  @override
  NodeDetailPageState createState() => new NodeDetailPageState();
}

class NodeDetailPageState extends State<NodeDetailPage> {
  GlobalKey _notesFormKey = new GlobalKey<FormState>();
  TextEditingController _nameController = TextEditingController();
  CDNBloc _cdnBloc;
  bool isRefresh = false;
  StreamSubscription _subscription;
  Api _api;
  List rates = [];

  @override
  void initState() {
    super.initState();
    _cdnBloc = BlocProvider.of<CDNBloc>(context);
    _subscription = _cdnBloc.listen((state) async {
      if (state is LoadSate) {
        if (mounted) {
          setState(() {
            if (widget.arguments.nshId == state.data.nshId) {
              widget.arguments.data = state.data.data;
            }
          });
          if (isRefresh) showToast('刷新成功！');
        }
      } else {
        NLog.v(state);
      }
    });
    _api = Api(mySecretKey: hexDecode(Global.minerData.se), myPublicKey: hexDecode(Global.minerData.pub), otherPubkey: hexDecode(Global.SERVER_PUBKEY));
    initData();
  }

  initData() {
//    String url = 'http://10.0.1.4:6080/api/v2/get_status_by_nshid/NKNVnLDSVhaw2DDRqDrKrWBL6ZanFy8ftTyf';
    String url = 'http://39.100.108.44:6443/api/v2/get_status_by_nshid/${Global.minerData.ads}';
    var params = {
      "beneficiary": Global.minerData.ads,
      "nshid": widget.arguments.nshId,
    };
    //[1592824857, "1771969.6916666667"]
    _api.post(url, params, isEncrypted: true).then((res) async {
      if (res != null && res.length != 0) {
        setState(() {
          rates = res;
        });
      }
    });
  }

  getRateView() {
    if (rates == null || rates.length == 0) {
      return Row(
        children: <Widget>[
          Label(
            '暂无数据',
            type: LabelType.bodyRegular,
            textAlign: TextAlign.start,
            color: Colors.black,
          ),
          Spacer()
        ],
      );
    } else {
      List<Widget> w = [];
      for (var m in rates) {
        try {
          if (m[1] == '0') continue;
          w.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Label(
                DateUtil.formatDateMs(m[0] * 1000),
                type: LabelType.bodyRegular,
                textAlign: TextAlign.start,
                color: Colors.black,
              ),
              Spacer(),
              Label(
                getFormatSize(double.parse(m[1])),
                type: LabelType.bodyRegular,
                color: Colors.black,
                textAlign: TextAlign.start,
              ),
            ],
          ));
        } catch (e) {}
      }
      return Column(
        children: w,
      );
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        title: '节点详情',
        backgroundColor: DefaultTheme.backgroundColor4,
        action: Button(
          padding: EdgeInsets.zero,
          icon: true,
          child: Label(
            '删除',
            color: Colors.white,
          ),
          onPressed: () {
            showDeleteDialog();
          },
        ),
      ),
      body: Builder(
        builder: (BuildContext context) => BodyBox(
          padding: EdgeInsets.only(top: 2.h, left: 16.w, right: 16.w),
          color: DefaultTheme.backgroundColor6,
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(top: 20.h),
              child: Column(
                children: <Widget>[
                  Label(
                    '预估收益',
                    type: LabelType.bodyRegular,
                    color: Colors.black,
                    textAlign: TextAlign.start,
                  ),
                  Label(
                    '${widget.arguments.cost != null ? Format.currencyFormat(widget.arguments.cost, decimalDigits: 3) : '-'} USDT',
                    type: LabelType.bodyLarge,
                    color: Colors.black,
                    fontSize: 20.sp,
                    textAlign: TextAlign.start,
                    fontWeight: FontWeight.bold,
                  ),
                  SizedBox(height: 20.h),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.all(12),
                        child: Column(
                          children: <Widget>[
                            InkWell(
                              onTap: () {
                                changeName();
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Label(
                                    '名称',
                                    type: LabelType.bodyRegular,
                                    color: DefaultTheme.fontColor2,
                                    textAlign: TextAlign.start,
                                  ),
                                  Spacer(),
                                  Label(
                                    widget.arguments.name,
                                    type: LabelType.bodyRegular,
                                    color: Colors.black,
                                    textAlign: TextAlign.start,
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Label(
                                  '流量',
                                  type: LabelType.bodyRegular,
                                  color: DefaultTheme.fontColor2,
                                  textAlign: TextAlign.start,
                                ),
                                Spacer(),
                                Label(
                                  '${widget.arguments.flow != null ? getFormatSize(widget.arguments.flow.toDouble(), unitArr: ['Bytes', 'KBytes', 'MBytes', 'GBytes', 'TBytes']) : '-'}',
                                  type: LabelType.bodyRegular,
                                  color: Colors.black,
                                  textAlign: TextAlign.start,
                                )
                              ],
                            ),
                            SizedBox(height: 10.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Label(
                                  '状态',
                                  type: LabelType.bodyRegular,
                                  color: DefaultTheme.fontColor2,
                                  textAlign: TextAlign.start,
                                ),
                                Spacer(),
                                Row(
                                  children: <Widget>[
                                    Label(
                                      widget.arguments.getStatus(),
                                      type: LabelType.bodyRegular,
                                      color: Colors.black,
                                      textAlign: TextAlign.start,
                                    )
                                  ],
                                )
                              ],
                            ),
                            SizedBox(height: 10.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Label(
                                  'IP地址',
                                  type: LabelType.bodyRegular,
                                  color: DefaultTheme.fontColor2,
                                  textAlign: TextAlign.start,
                                ),
                                Spacer(),
                                Label(
                                  widget.arguments.getIp(),
                                  type: LabelType.bodyRegular,
                                  color: Colors.black,
                                  textAlign: TextAlign.start,
                                )
                              ],
                            ),
                            SizedBox(height: 10.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Label(
                                  '磁盘总容量',
                                  type: LabelType.bodyRegular,
                                  color: DefaultTheme.fontColor2,
                                  textAlign: TextAlign.start,
                                ),
                                Spacer(),
                                Label(
                                  widget.arguments.getCapacity(),
                                  type: LabelType.bodyRegular,
                                  color: Colors.black,
                                  textAlign: TextAlign.start,
                                )
                              ],
                            ),
                            SizedBox(height: 10.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Label(
                                  '已用空间数',
                                  type: LabelType.bodyRegular,
                                  color: DefaultTheme.fontColor2,
                                  textAlign: TextAlign.start,
                                ),
                                Spacer(),
                                Label(
                                  widget.arguments.getUsed(),
                                  type: LabelType.bodyRegular,
                                  color: Colors.black,
                                  textAlign: TextAlign.start,
                                )
                              ],
                            ),
                            SizedBox(height: 10.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Label(
                                  'MAC地址',
                                  type: LabelType.bodyRegular,
                                  color: DefaultTheme.fontColor2,
                                  textAlign: TextAlign.start,
                                ),
                                Spacer(),
                                Label(
                                  widget.arguments.getMacAddress(),
                                  type: LabelType.bodyRegular,
                                  color: Colors.black,
                                  textAlign: TextAlign.start,
                                )
                              ],
                            ),
                            SizedBox(height: 10.h),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Label(
                                  'NKN ID',
                                  type: LabelType.bodyRegular,
                                  color: DefaultTheme.fontColor2,
                                  textAlign: TextAlign.start,
                                ),
                                SizedBox(height: 4.h),
                                InkWell(
                                  onTap: () {
                                    if (widget.arguments.nshId != null) CopyUtils.copyAction(context, json.encode(widget.arguments.nshId));
                                  },
                                  child: Label(
                                    widget.arguments.nshId,
                                    type: LabelType.bodyRegular,
                                    color: Colors.black,
                                    textAlign: TextAlign.start,
                                    softWrap: true,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10.h),
                          ],
                        ),
                      ),
                      getParamsView(),
                      SizedBox(height: 10.h),
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.all(12),
                        child: Column(
                          children: <Widget>[
                            InkWell(
                              onTap: () {
                                isRefresh = true;
                                widget.arguments.getMinerDetail();
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Label(
                                    '近期速率',
                                    type: LabelType.bodyRegular,
                                    color: DefaultTheme.fontColor2,
                                    textAlign: TextAlign.start,
                                  ),
                                  Spacer(),
                                ],
                              ),
                            ),
                            SizedBox(height: 10.h),
                            getRateView()
                          ],
                        ),
                      ),
                      SizedBox(height: 40.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: <Widget>[
                          InkWell(
                            onTap: () {
                              showToast('已发送指令');
                              isRefresh = true;
                              widget.arguments.getMinerDetail();
                            },
                            child: Container(
                              decoration: BoxDecoration(color: DefaultTheme.primaryColor, borderRadius: BorderRadius.circular(10)),
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: Row(
                                children: <Widget>[
                                  Label(
                                    '刷新状态',
                                    type: LabelType.bodyRegular,
                                    color: Colors.white,
                                    textAlign: TextAlign.start,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              showRebootDialog();
                            },
                            child: Container(
                              decoration: BoxDecoration(color: DefaultTheme.primaryColor, borderRadius: BorderRadius.circular(10)),
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: Row(
                                children: <Widget>[
                                  Label(
                                    '重启设备',
                                    type: LabelType.bodyRegular,
                                    color: Colors.white,
                                    textAlign: TextAlign.start,
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
//                      Row(
//                        mainAxisAlignment: MainAxisAlignment.spaceAround,
//                        children: <Widget>[
//                          InkWell(
//                            onTap: () {
//                              showToast('已发送指令');
//                              isRefresh = true;
//                              widget.arguments.getMinerDetail();
//                            },
//                            child: Container(
//                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
//                              padding: EdgeInsets.all(12),
//                              child: Row(
//                                children: <Widget>[
//                                  Label(
//                                    '刷新状态',
//                                    type: LabelType.bodyRegular,
//                                    color: DefaultTheme.fontColor2,
//                                    textAlign: TextAlign.start,
//                                  ),
////                                  Spacer(),
//                                  SizedBox(width: 20),
//                                  Icon(
//                                    Icons.refresh,
//                                    size: 24,
//                                    color: DefaultTheme.primaryColor,
//                                  )
//                                ],
//                              ),
//                            ),
//                          ),
//                          InkWell(
//                            onTap: () {
//                              showRebootDialog();
//                            },
//                            child: Container(
//                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
//                              padding: EdgeInsets.all(12),
//                              child: Row(
//                                children: <Widget>[
//                                  Label(
//                                    '重启设备',
//                                    type: LabelType.bodyRegular,
//                                    color: DefaultTheme.fontColor2,
//                                    textAlign: TextAlign.start,
//                                  ),
////                                  Spacer(),
//                                  SizedBox(width: 20),
//                                  Icon(
//                                    Icons.offline_bolt,
//                                    color: Colors.red,
//                                  )
//                                ],
//                              ),
//                            ),
//                          ),
//                        ],
//                      ),
                      SizedBox(height: 30.h),
                    ],
                  ),
                ],
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

  changeName() {
    BottomDialog.of(context).showBottomDialog(
      height: 320,
      title: '修改名称',
      child: Form(
        key: _notesFormKey,
        autovalidate: true,
        child: Flex(
          direction: Axis.horizontal,
          children: <Widget>[
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Label(
                      '名称',
                      type: LabelType.h4,
                      textAlign: TextAlign.start,
                    ),
                    Textbox(
                      multi: true,
                      minLines: 1,
                      maxLines: 3,
                      controller: _nameController,
                      textInputAction: TextInputAction.newline,
                      maxLength: 200,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      action: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 34),
        child: Button(
          text: '保存',
          width: double.infinity,
          onPressed: () async {
            if (_nameController.text.toString().length > 0) {
              setState(() {
                widget.arguments.name = _nameController.text.toString();
                widget.arguments.insertOrUpdate();
              });
            }
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  showRebootDialog() {
    showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return Container(
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.w)),
              title: Label(
                '提示',
                type: LabelType.h2,
                softWrap: true,
              ),
              content: Container(
                constraints: BoxConstraints(minWidth: double.infinity / 4 * 5),
                child: SingleChildScrollView(
                  child: Label(
                    '重启过程需要等待几分钟，您确定要重启该设备吗？',
                    type: LabelType.bodyRegular,
                    softWrap: true,
                  ),
                ),
              ),
              actions: <Widget>[
                FlatButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Navigator.pop(context);
                      widget.arguments.reboot();
                      showToast('已发送重启指令！');
                    },
                    child: Label(
                      '确定',
                      type: LabelType.h3,
                    )),
                FlatButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Label(
                      '取消',
                      type: LabelType.h3,
                      color: DefaultTheme.fontColor2,
                    )),
              ],
            ),
          );
        });
  }

  showDeleteDialog() {
    showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return Container(
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.w)),
              title: Label(
                '提示',
                type: LabelType.h2,
                softWrap: true,
              ),
              content: Container(
                constraints: BoxConstraints(minWidth: double.infinity / 4 * 5),
                child: SingleChildScrollView(
                  child: Label(
                    '您确定要删除该设备吗？',
                    type: LabelType.bodyRegular,
                    softWrap: true,
                  ),
                ),
              ),
              actions: <Widget>[
                FlatButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Navigator.pop(context);
                      deleteAction();
                    },
                    child: Label(
                      '删除',
                      type: LabelType.h3,
                    )),
                FlatButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Label(
                      '取消',
                      type: LabelType.h3,
                      color: DefaultTheme.fontColor2,
                    )),
              ],
            ),
          );
        });
  }

  deleteAction() {
    widget.arguments.delete();
    _cdnBloc.add(LoadData(data: widget.arguments));
    Navigator.of(context).pop(widget.arguments);
  }

  getParamsView() {
    if (widget.arguments.data == null) {
      return Container();
    } else {
      return Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Label(
                  '设备参数',
                  type: LabelType.bodyRegular,
                  color: DefaultTheme.fontColor2,
                  textAlign: TextAlign.start,
                ),
              ],
            ),
            SizedBox(height: 4.h),
            InkWell(
              onTap: () {
                if (widget.arguments.data != null) CopyUtils.copyAction(context, json.encode(widget.arguments.data));
              },
              child: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(color: Color(0xFFE5E5E5), borderRadius: BorderRadius.circular(10)),
                child: Label(
                  widget.arguments.data == null ? '未知' : widget.arguments.data.toString(),
                  type: LabelType.bodyRegular,
                  color: Colors.black,
                  textAlign: TextAlign.start,
                  softWrap: true,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}

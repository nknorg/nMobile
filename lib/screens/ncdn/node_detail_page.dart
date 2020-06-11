import 'dart:convert';

import 'package:common_utils/common_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/textbox.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/schemas/cdn_miner.dart';
import 'package:nmobile/utils/copy_utils.dart';

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

  @override
  void initState() {
    super.initState();
    LogUtil.v('onCreate', tag: 'NodeDetailPage');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        title: '节点详情',
        backgroundColor: DefaultTheme.backgroundColor4,
//        action: Button(
//          padding: EdgeInsets.zero,
//          icon: true,
//          child: Label(
//            '删除',
//            color: Colors.white,
//          ),
//          onPressed: () {
//            showDeleteDialog();
//          },
//        ),
      ),
      body: Builder(
        builder: (BuildContext context) => BodyBox(
          padding: EdgeInsets.only(top: 2.h, left: 16.w, right: 16.w),
          color: DefaultTheme.backgroundLightColor,
          child: Padding(
            padding: EdgeInsets.only(top: 20.h),
            child: Column(
              children: <Widget>[
                Label(
                  '昨日收益',
                  type: LabelType.bodyRegular,
                  color: DefaultTheme.fontColor2,
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
                        Label(
                          widget.arguments.getStatus(),
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
                          '磁盘总用量',
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
                        Label(
                          widget.arguments.nshId,
                          type: LabelType.bodyRegular,
                          color: Colors.black,
                          textAlign: TextAlign.start,
                          softWrap: true,
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Column(
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
                  ],
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
                constraints: BoxConstraints(minHeight: 100.h, maxHeight: 400.h, minWidth: double.infinity / 4 * 5),
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
    Navigator.of(context).pop();
  }
}

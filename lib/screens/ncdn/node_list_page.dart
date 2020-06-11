import 'package:common_utils/common_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/schemas/cdn_miner.dart';
import 'package:nmobile/screens/ncdn/node_detail_page.dart';

class NodeListPage extends StatefulWidget {
  static final String routeName = "NodeListPage";
  final List<CdnMiner> arguments;

  NodeListPage({Key key, this.arguments}) : super(key: key);

  @override
  NodeListPageState createState() => new NodeListPageState();
}

class NodeListPageState extends State<NodeListPage> {
  List<CdnMiner> _list = <CdnMiner>[];

  @override
  void initState() {
    super.initState();
    LogUtil.v('onCreate', tag: 'NodeListPage');
    _list = widget.arguments;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.backgroundColor4,
      appBar: Header(
        title: '节点详情',
        backgroundColor: DefaultTheme.backgroundColor4,
      ),
      body: Builder(
        builder: (BuildContext context) => BodyBox(
          padding: EdgeInsets.only(top: 2, left: 16.w, right: 16.w),
          color: DefaultTheme.backgroundColor6,
          child: Padding(
            padding: EdgeInsets.only(top: 20.h),
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
                                    '昨日收益: ${node.cost != null ? Format.currencyFormat(node.cost, decimalDigits: 3) : '-'} USDT',
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

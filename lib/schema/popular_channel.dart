import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';

class PopularChannel {
  final Color titleColor;
  final Color titleBgColor;
  final String title;
  final String subTitle;
  final String topic;
  final String desc;

  PopularChannel(this.titleColor, this.titleBgColor, this.title, this.subTitle, this.topic, this.desc);

  static defaultData() {
    List<PopularChannel> lists = [];
    lists.add(PopularChannel(application.theme.randomColorList[0], application.theme.randomBackgroundColorList[0], 'DC', '#d-chat', "d-chat", 'Welcome to join the D-Chat group'));
    lists.add(PopularChannel(application.theme.randomColorList[5], application.theme.randomBackgroundColorList[5], '中', '#中文', "中文", "Chinese group"));
    lists.add(PopularChannel(application.theme.randomColorList[1], application.theme.randomBackgroundColorList[1], 'NC', '#nkn-chat', "nkn-chat", 'To join the developer group'));
    lists.add(PopularChannel(application.theme.randomColorList[4], application.theme.randomBackgroundColorList[4], 'S', '#sport', "sport", "Let's play together"));
    return lists;
  }
}

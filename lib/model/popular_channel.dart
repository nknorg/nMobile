import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/consts/theme.dart';

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
    lists.add(PopularChannel(Color(DefaultTheme.headerColor1), Color(DefaultTheme.headerBackgroundColor1), 'DC', '#d-chat', "d-chat", 'Welcome to join the D-Chat group'));
    lists.add(PopularChannel(Color(DefaultTheme.headerColor6), Color(DefaultTheme.headerBackgroundColor6), '中', '#中文', "中文", "Chinese group"));
    lists.add(PopularChannel(Color(DefaultTheme.headerColor2), Color(DefaultTheme.headerBackgroundColor2), 'NC', '#nkn-chat', "nkn-chat", 'To join the developer group'));
//    lists.add(PopularChannel(Color(DefaultTheme.headerColor4), Color(DefaultTheme.headerBackgroundColor4), 'M', '#music', "Music", 'Love music'));
    lists.add(PopularChannel(Color(DefaultTheme.headerColor5), Color(DefaultTheme.headerBackgroundColor5), 'S', '#sport', "sport", "Let's play together"));
    return lists;
  }
}

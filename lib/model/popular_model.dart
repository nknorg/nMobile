import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/consts/theme.dart';

class PopularModel {
  final Color titleColor;
  final Color titleBgColor;
  final String title;
  final String subTitle;
  final String topic;
  final String desc;

  PopularModel(this.titleColor, this.titleBgColor, this.title, this.subTitle, this.topic, this.desc);

  static List<PopularModel> defaultData() {
    List<PopularModel> lists = [];
    lists.add(PopularModel(Color(DefaultTheme.headerColor1), Color(DefaultTheme.headerBackgroundColor1), 'DC', '#d-chat', "d-chat", 'Welcome to join the D-Chat group'));
    lists.add(PopularModel(Color(DefaultTheme.headerColor2), Color(DefaultTheme.headerBackgroundColor2), 'NC', '#nkn-chat', "nkn-chat", 'To join the developer group'));
//    lists.add(PopularModel(Color(DefaultTheme.headerColor4), Color(DefaultTheme.headerBackgroundColor4), 'M', '#music', "Music", 'Love music'));
    lists.add(PopularModel(Color(DefaultTheme.headerColor5), Color(DefaultTheme.headerBackgroundColor5), 'S', '#sport', "sport", "Let's play together"));
    lists.add(PopularModel(Color(DefaultTheme.headerColor6), Color(DefaultTheme.headerBackgroundColor6), '中', '#中文', "中文", "Chinese group"));
    return lists;
  }
}

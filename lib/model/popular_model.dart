import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/consts/theme.dart';

class PopularModel {
  final Color titleColor;
  final Color titleBgColor;
  final String title;
  final String subTitle;
  final String topic;

  PopularModel(this.titleColor, this.titleBgColor, this.title, this.subTitle, this.topic);

  static defaultData() {
    List<PopularModel> lists = [];
    lists.add(PopularModel(Color(DefaultTheme.headerColor1), Color(DefaultTheme.headerBackgroundColor1), 'DC', '#d-chat', "d-chat"));
    lists.add(PopularModel(Color(DefaultTheme.headerColor2), Color(DefaultTheme.headerBackgroundColor2), 'NC', '#nkn-chat', "nkn-chat"));
    lists.add(PopularModel(Color(DefaultTheme.headerColor3), Color(DefaultTheme.headerBackgroundColor3), 'C', '#cats', "cats"));
    lists.add(PopularModel(Color(DefaultTheme.headerColor4), Color(DefaultTheme.headerBackgroundColor4), 'M', '#music', "中文"));
    lists.add(PopularModel(Color(DefaultTheme.headerColor5), Color(DefaultTheme.headerBackgroundColor5), 'S', '#sport', "sport"));
    lists.add(PopularModel(Color(DefaultTheme.headerColor6), Color(DefaultTheme.headerBackgroundColor6), '中', '#中文', "中文"));
    return lists;
  }
}

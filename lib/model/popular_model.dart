import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PopularModel {
  final Color titleColor;
  final Color titleBgColor;
  final String title;
  final String subTitle;
  final String topic;

  PopularModel(this.titleColor, this.titleBgColor, this.title, this.subTitle, this.topic);

  static defaultData() {
    List<PopularModel> lists = [];
    lists.add(PopularModel(Color(0xFF00CC96), Color(0x1900CC96), 'DC', '#d-chat', "d-chat"));
    lists.add(PopularModel(Color(0xFFFC5D68), Color(0x19FC5D68), 'NC', '#nkn-chat', "nkn-chat"));
    lists.add(PopularModel(Color(0xFF5458F7), Color(0x195458F7), '中', '#中文', "中文"));
    return lists;
  }
}

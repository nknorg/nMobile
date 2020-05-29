import 'package:flutter/material.dart';
import 'package:nmobile/consts/theme.dart';

class Tabs extends StatefulWidget {
  final List<String> tabs;
  TabController controller;
  Tabs({this.tabs, this.controller});
  @override
  _TabsState createState() => _TabsState();
}

class _TabsState extends State<Tabs> with SingleTickerProviderStateMixin {

  @override
  void initState() {
    super.initState();
    widget.controller = widget.controller ?? TabController(length: widget.tabs.length, vsync: this);
  }


  @override
  Widget build(BuildContext context) {
    return  DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: DefaultTheme.backgroundColor2))),
      child: TabBar(
          labelStyle: TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
          controller: widget.controller,
          labelColor: DefaultTheme.primaryColor,
          unselectedLabelColor: DefaultTheme.fontColor2,
          tabs: widget.tabs.map((e) => Tab(text: e)).toList()),
    );
  }
}

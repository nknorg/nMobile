import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';

class Tabs extends StatefulWidget {
  List<String> titles;
  TabController? controller;

  Tabs({
    required this.titles,
    this.controller,
  });

  @override
  _TabsState createState() => _TabsState();
}

class _TabsState extends State<Tabs> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    widget.controller = widget.controller ?? TabController(length: widget.titles.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
          border: Border(
        bottom: BorderSide(color: application.theme.backgroundColor2),
      )),
      child: TabBar(
        labelStyle: TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
        controller: widget.controller,
        labelColor: application.theme.primaryColor,
        unselectedLabelColor: application.theme.fontColor2,
        tabs: widget.titles.map((e) => Tab(text: e)).toList(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';

class Tabs extends BaseStateFulWidget {
  List<String> titles;
  TabController? controller;

  Tabs({
    required this.titles,
    this.controller,
  });

  @override
  _TabsState createState() => _TabsState();
}

class _TabsState extends BaseStateFulWidgetState<Tabs> with SingleTickerProviderStateMixin {
  late TabController _controller;

  @override
  void onRefreshArguments() {
    this._controller = widget.controller ?? TabController(length: widget.titles.length, vsync: this);
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
        controller: this._controller,
        labelColor: application.theme.primaryColor,
        unselectedLabelColor: application.theme.fontColor2,
        tabs: widget.titles.map((e) => Tab(text: e)).toList(),
      ),
    );
  }
}

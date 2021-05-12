import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';

class Layout extends StatefulWidget {
  final Key key;
  final Color headerColor;
  final PreferredSizeWidget header;
  final Color bodyColor;
  final Widget body;
  final Widget floatingActionButton;
  final FloatingActionButtonLocation floatingActionButtonLocation;

  Layout({
    this.key,
    this.header,
    this.body,
    this.headerColor,
    this.bodyColor,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  @override
  _LayoutState createState() => _LayoutState();
}

class _LayoutState extends State<Layout> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: widget.key,
      backgroundColor: widget.headerColor ?? application.theme.headBarColor1,
      appBar: widget.header,
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      body: Container(
        constraints: BoxConstraints.expand(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: PhysicalModel(
          color: widget.bodyColor ?? application.theme.backgroundColor,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          child: Column(
            children: <Widget>[
              Expanded(
                flex: 1,
                child: widget.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

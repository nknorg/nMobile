import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';

class Layout extends StatefulWidget {
  final Key key;
  final Color headerColor;
  final PreferredSizeWidget header;
  final Color color;
  final Widget child;

  Layout({
    this.key,
    this.headerColor,
    this.header,
    this.color,
    this.child,
  });

  @override
  _LayoutState createState() => _LayoutState();
}

class _LayoutState extends State<Layout> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: widget.key,
      backgroundColor: widget.headerColor,
      appBar: widget.header,
      body: Container(
        constraints: BoxConstraints.expand(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: PhysicalModel(
          color: widget.color ?? application.theme.backgroundColor,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          child: Column(
            children: <Widget>[
              Expanded(
                flex: 1,
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

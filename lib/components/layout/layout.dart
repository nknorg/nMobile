import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';

class Layout extends StatefulWidget {
  final Key key;
  final PreferredSizeWidget header;
  final Color color;
  final Color headerColor;
  final Widget child;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  Layout({
    this.key,
    this.header,
    this.child,
    this.color,
    this.headerColor,
    this.actions,
    this.padding,
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
          child: Flex(
            direction: Axis.vertical,
            children: <Widget>[
              Expanded(
                flex: 1,
                child: Container(
                  padding: widget.padding,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
                  ),
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

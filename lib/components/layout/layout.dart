import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';

class Layout extends StatefulWidget {
  final Key? key;
  final Color headerColor;
  final PreferredSizeWidget? header;
  final Color? bodyColor;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final BorderRadius? borderRadius;

  Layout({
    this.key,
    required this.headerColor,
    this.header,
    this.bodyColor,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(32)),
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
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      body: Container(
        constraints: BoxConstraints.expand(),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: PhysicalModel(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          color: widget.bodyColor ?? application.theme.backgroundColor,
          borderRadius: widget.borderRadius ?? BorderRadius.vertical(top: Radius.circular(32)),
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

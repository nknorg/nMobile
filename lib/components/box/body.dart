import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/consts/theme.dart';

class BodyBox extends StatefulWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  BodyBox({this.child, this.color, this.padding});

  @override
  _BodyBoxState createState() => _BodyBoxState();
}

class _BodyBoxState extends State<BodyBox> {
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints.expand(),
      decoration: BoxDecoration(
        color: widget.color ?? DefaultTheme.backgroundColor1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Flex(
        direction: Axis.vertical,
        children: <Widget>[
          Expanded(
            flex: 1,
            child: Container(
              padding: widget.padding ?? const EdgeInsets.only(top: 32, left: 20, right: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

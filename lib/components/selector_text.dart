import 'dart:async';

import 'package:flutter/material.dart';

class TextSelector extends StatefulWidget {
  final String text;
  final double fontSize;
  final Color color;
  final Color colorPressed;
  final FontStyle fontStyle;
  final FontWeight fontWeight;
  final TextDecoration decoration;
  final VoidCallback onTap;

  const TextSelector(this.text, this.fontSize, this.color, this.colorPressed,
      {this.fontStyle: FontStyle.normal, this.fontWeight: FontWeight.normal, this.decoration: TextDecoration.none, this.onTap});

  @override
  _SelectorState createState() => _SelectorState();
}

class _SelectorState extends State<TextSelector> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTapDown: (details) {
          setState(() {
            _pressed = true;
          });
        },
        onTapCancel: () {
          setState(() {
            _pressed = false;
          });
        },
        onTapUp: (details) {
          setState(() {
            _pressed = false;
          });
        },
        onTap: () {
          setState(() {
            _pressed = true;
            Timer(Duration(milliseconds: 100), () {
              setState(() {
                _pressed = false;
              });
            });
          });
          if (widget.onTap != null) widget.onTap();
        },
        child: Text(widget.text,
            style: TextStyle(
                fontSize: widget.fontSize,
                color: _pressed ? widget.colorPressed : widget.color,
                fontStyle: widget.fontStyle,
                fontWeight: widget.fontWeight,
                decoration: widget.decoration)));
  }
}

import 'package:flutter/material.dart';

class ChatSystem extends StatefulWidget {
  Widget child;

  ChatSystem({this.child});

  @override
  _ChatSystemState createState() => _ChatSystemState();
}

class _ChatSystemState extends State<ChatSystem> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(8),
          child: widget.child,
        ),
      ),
    );
  }
}

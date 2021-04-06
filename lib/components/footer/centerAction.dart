import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class CenterAction extends StatefulWidget {
  @override
  CenterActionState createState() => new CenterActionState();
}

class CenterActionState extends State<CenterAction> {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      child: Image.asset(
        'assets/logo.png',
        height: 30,
      ),
      onPressed: () => {},
    );
  }
}

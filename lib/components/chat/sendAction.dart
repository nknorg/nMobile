import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SendAction extends StatefulWidget {
  @override
  _SendActionState createState() => new _SendActionState();
}

class _SendActionState extends State<SendAction> {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      child: SvgPicture.asset(
        'assets/chat/send.svg',
        color: Colors.white,
      ),
      onPressed: () => {},
    );
  }
}

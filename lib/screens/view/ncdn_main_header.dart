import 'package:flutter/material.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';

class NcdnMainPage {
  static getHeader(context, onPressed) {
    return Header(
      title: '节点明细',
      backgroundColor: DefaultTheme.backgroundColor4,
      action: Button(
        padding: EdgeInsets.zero,
        icon: true,
        child: Label(
          '添加',
          color: Colors.white,
        ),
        onPressed: onPressed,
      ),
    );
  }
}

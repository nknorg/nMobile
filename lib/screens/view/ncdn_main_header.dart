import 'package:flutter/material.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';

class NcdnMainPage {
  static getHeader(context, onPressed) {
    return Header(
      title: NMobileLocalizations.of(context).node_detail,
      backgroundColor: DefaultTheme.backgroundColor4,
      action: FlatButton(
        child: Label(
          NMobileLocalizations.of(context).add_text,
          color: Colors.white,
        ),
        onPressed: onPressed,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';

class SimpleConfirm {
  final BuildContext context;
  final String title;
  final String content;
  final String buttonText;
  final Color buttonColor;
  final ValueChanged<bool> callback;

  SimpleConfirm(
      {@required this.context,
      this.title,
      @required this.content,
      this.callback,
      this.buttonText,
      this.buttonColor});

  Future<void> show() {
    String title = this.title;
    String buttonText = this.buttonText;
    if (title == null || title.isEmpty) title = NL10ns.of(context).tip;
    if (buttonText == null || buttonText.isEmpty)
      buttonText = NL10ns.of(context).ok;
    return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title,
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w500)),
            content: Text(content,
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            actions: <Widget>[
              FlatButton(
                child: Text(NL10ns.of(context).cancel.toUpperCase(),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: DefaultTheme.fontColor2)),
                onPressed: () {
                  Navigator.of(context).pop();
                  if (callback != null) callback(false);
                },
              ),
              FlatButton(
                child: Text(buttonText.toUpperCase(),
                    style: TextStyle(
                        color: buttonColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.of(context).pop();
                  if (callback != null) callback(true);
                },
              )
            ],
          );
        });
  }
}

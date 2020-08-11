import 'package:flutter/material.dart';
import 'package:nmobile/l10n/localization_intl.dart';

class SimpleAlert {
  final BuildContext context;
  final String title;
  final String content;
  final String buttonText;
  final VoidCallback callback;

  SimpleAlert({@required this.context, this.title, @required this.content, this.callback, this.buttonText});

  Future<void> show() {
    String title = this.title;
    String buttonText = this.buttonText;
    if (title == null || title.isEmpty) title = NL10ns.of(context).tip;
    if (buttonText == null || buttonText.isEmpty) buttonText = NL10ns.of(context).ok;
    return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title, style: TextStyle(color: Colors.grey[700], fontSize: 18, fontWeight: FontWeight.w500)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Text(content, style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            actions: <Widget>[
              FlatButton(
                child: Text(buttonText.toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                onPressed: () {
                  Navigator.of(context).pop();
                  if (callback != null) callback();
                },
              )
            ],
          );
        });
  }
}

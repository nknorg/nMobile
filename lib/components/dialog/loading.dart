import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:nmobile/consts/theme.dart';

class LoadingDialog extends StatefulWidget {
  @override
  _LoadingDialogState createState() => _LoadingDialogState();

  BuildContext context;
  LoadingDialog();

  LoadingDialog.of(this.context);

  show() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Container(
          alignment: Alignment.center,
          child: this,
        );
      },
    );
  }

  close() {
    Navigator.of(context).pop();
  }
}

class _LoadingDialogState extends State<LoadingDialog> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SpinKitFadingCircle(
      color: DefaultTheme.loadingColor,
      size: 80,
    );
  }
}

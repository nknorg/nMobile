import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/components/text/label.dart';

class Loading {
  static void dismiss() {
    BotToast.closeAllLoading();
  }

  static show({String? text}) {
    if (text?.isNotEmpty == true) {
      BotToast.showCustomLoading(toastBuilder: (cancelFunc) {
        return Container(
          constraints: BoxConstraints(
            maxWidth: Global.screenHeight() / 4,
          ),
          padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 10),
              CircularProgressIndicator(
                backgroundColor: Colors.white,
              ),
              SizedBox(height: 20),
              Label(
                text ?? "",
                type: LabelType.display,
                softWrap: true,
              ),
            ],
          ),
        );
      });
    } else {
      BotToast.showLoading();
    }
  }
}

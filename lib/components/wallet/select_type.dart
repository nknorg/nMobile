import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/schema/wallet.dart';

import 'item.dart';

class WalletSelectType {
  static Future<String> show({@required BuildContext context, @required String title, String desc}) {
    var bottomDialog = BottomDialog.of(context);
    return bottomDialog.showWithTitle<String>(
      title: title,
      desc: desc,
      height: 330,
      child: Column(
        children: [
          InkWell(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: WalletItem(type: WalletType.nkn),
            ),
            onTap: () {
              bottomDialog.close(result: WalletType.nkn);
            },
          ),
          Divider(height: 1, indent: 64),
          InkWell(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: WalletItem(type: WalletType.eth),
            ),
            onTap: () {
              bottomDialog.close(result: WalletType.eth);
            },
          ),
          Divider(height: 1, indent: 64),
        ],
      ),
    );
  }
}

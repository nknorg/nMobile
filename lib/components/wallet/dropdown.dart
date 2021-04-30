import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/assets.dart';

import 'item.dart';

class WalletDropdown extends StatefulWidget {
  final WalletSchema schema;

  WalletDropdown({this.schema});

  @override
  _WalletDropdownState createState() => _WalletDropdownState();
}

class _WalletDropdownState extends State<WalletDropdown> {
  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);

    return InkWell(
      onTap: () {
        BottomDialog.of(context).showBottomDialog(
          title: _localizations.select_another_wallet,
          child: ListView.builder(
            itemCount: 10,
            itemExtent: 81,
            padding: const EdgeInsets.all(0),
            itemBuilder: (BuildContext context, int index) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    WalletItem(type: WalletType.nkn),
                    Divider(height: 1, indent: 64),
                  ],
                ),
              );
            },
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: application.theme.backgroundColor2)),
        ),
        child: WalletItem(
          type: WalletType.nkn,
          leading: Expanded(
            flex: 0,
            child: Container(
              alignment: Alignment.centerRight,
              height: 44,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: assetIcon('down2', width: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/assets.dart';
import 'package:nmobile/utils/logger.dart';

import 'item.dart';

class WalletDropdown extends StatefulWidget {
  final WalletSchema schema;
  final Function(WalletSchema) onSelected;
  final Color bgColor;

  WalletDropdown({
    this.schema,
    this.onSelected,
    this.bgColor,
  });

  @override
  _WalletDropdownState createState() => _WalletDropdownState();
}

class _WalletDropdownState extends State<WalletDropdown> {
  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);

    return InkWell(
      onTap: () async {
        WalletSchema result = await BottomDialog.of(context).showWalletSelect(title: _localizations.select_another_wallet);
        logger.d("wallet dropdown select - $result");
        widget.onSelected?.call(result);
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: widget.bgColor ?? application.theme.backgroundColor2),
          ),
        ),
        child: WalletItem(
          type: widget.schema?.type ?? WalletType.nkn,
          tail: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: assetIcon('down2', width: 24),
          ),
        ),
      ),
    );
  }
}

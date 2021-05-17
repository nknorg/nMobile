import 'package:flutter/material.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/asset.dart';
import 'package:nmobile/helpers/logger.dart';
import 'package:nmobile/schema/wallet.dart';

import 'item.dart';

class WalletDropdown extends StatefulWidget {
  final WalletSchema schema;
  final String selectTitle;
  final Function(WalletSchema) onSelected;
  final Color bgColor;

  WalletDropdown({
    this.schema,
    this.selectTitle,
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

    return WalletItem(
      type: widget.schema?.type ?? WalletType.nkn,
      schema: widget.schema,
      radius: BorderRadius.circular(8),
      padding: EdgeInsets.all(0),
      bgColor: Colors.transparent,
      tail: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Asset.iconSvg('down2', width: 24),
      ),
      onTap: () async {
        WalletSchema result = await BottomDialog.of(context).showWalletSelect(
          title: widget.selectTitle ?? _localizations.select_another_wallet,
        );
        logger.d("wallet dropdown select - $result");
        widget.onSelected?.call(result);
      },
    );
  }
}

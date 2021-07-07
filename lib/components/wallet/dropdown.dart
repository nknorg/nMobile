import 'package:flutter/material.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';

import 'item.dart';

class WalletDropdown extends StatelessWidget with Tag {
  final WalletSchema wallet;
  final String? selectTitle;
  final Function(WalletSchema)? onSelected;
  final Color? bgColor;
  final bool onTapWave;

  WalletDropdown({
    required this.wallet,
    this.selectTitle,
    this.onSelected,
    this.bgColor,
    this.onTapWave = true,
  });

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);

    return WalletItem(
      walletType: this.wallet.type,
      wallet: this.wallet,
      radius: BorderRadius.circular(8),
      padding: EdgeInsets.all(0),
      bgColor: Colors.transparent,
      onTapWave: this.onTapWave,
      tail: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Asset.iconSvg('down2', width: 24),
      ),
      onTap: () async {
        WalletSchema? result = await BottomDialog.of(context).showWalletSelect(
          title: this.selectTitle ?? _localizations.select_another_wallet,
        );
        logger.d("$TAG - wallet dropdown select - $result");
        if (result != null) {
          this.onSelected?.call(result);
        }
      },
    );
  }
}

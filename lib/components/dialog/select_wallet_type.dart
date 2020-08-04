import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nmobile/components/wallet/item.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/utils/extensions.dart';

class SelectWalletTypeDialog extends StatefulWidget {
  @override
  _SelectWalletTypeDialogState createState() => _SelectWalletTypeDialogState();
  final BuildContext _context;

  SelectWalletTypeDialog.of(this._context);

  Future<WalletType> show() {
    return showModalBottomSheet<WalletType>(
      context: _context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      backgroundColor: DefaultTheme.backgroundLightColor,
      builder: (BuildContext context) {
        return AnimatedPadding(
          padding: MediaQuery.of(context).viewInsets,
          duration: const Duration(milliseconds: 100),
          child: this,
        );
      },
    );
  }

  close({WalletType type}) {
    Navigator.of(_context).pop(type);
  }
}

class _SelectWalletTypeDialogState extends State<SelectWalletTypeDialog> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 375,
      constraints: BoxConstraints(minHeight: 200),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(2)),
              color: Colours.light_e9,
            ),
          ).center.pad(t: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                NMobileLocalizations.of(context).select_wallet_type,
                style: TextStyle(fontSize: DefaultTheme.h2FontSize, color: Colours.dark_2d, fontWeight: FontWeight.bold),
              ),
              Text(
                NMobileLocalizations.of(context).select_wallet_type_desc,
                style: TextStyle(fontSize: DefaultTheme.h4FontSize, color: Colours.gray_81),
              ).pad(t: 8),
              _getItemNkn(context),
              Container(height: 1, color: Colours.light_e9).pad(l: 64, t: 16),
              _getItemEth(context),
              Container(height: 1, color: Colours.light_e9).pad(l: 64, t: 16),
            ],
          ).pad(l: 20, t: 32, r: 20),
        ],
      ),
    );
  }

  Widget _getItemNkn(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            color: Colours.light_ff,
          ),
          child: SvgPicture.asset('assets/logo.svg', color: Colours.purple_2e),
        ),
        Text(
          NMobileLocalizations.of(context).nkn_mainnet,
          style: TextStyle(fontSize: DefaultTheme.h3FontSize, color: Colours.dark_2d, fontWeight: FontWeight.bold),
        ).pad(l: 16),
        Spacer(),
        Container(
          alignment: Alignment.center,
          padding: 2.pad(l: 8, r: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(9)), color: Colours.green_06_a1p),
          child: Text(
            NMobileLocalizations.of(context).mainnet,
            style: TextStyle(color: Colours.green_06, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        )
      ],
    ).pad(t: 24).inkWell(() {
      widget.close(type: WalletType.nkn);
    });
  }

  Widget _getItemEth(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            color: Colours.light_ff,
          ),
          child: SvgPicture.asset('assets/icon_eth_15_24.svg', color: Colours.purple_53),
        ),
        Text(
          NMobileLocalizations.of(context).ethereum,
          style: TextStyle(fontSize: DefaultTheme.h3FontSize, color: Colours.dark_2d, fontWeight: FontWeight.bold),
        ).pad(l: 16),
        Spacer(),
        Container(
          alignment: Alignment.center,
          padding: 2.pad(l: 8, r: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(9)), color: Colours.purple_53_a1p),
          child: Text(
            NMobileLocalizations.of(context).ERC_20,
            style: TextStyle(color: Colours.purple_53, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        )
      ],
    ).pad(t: 24).inkWell(() {
      widget.close(type: WalletType.eth);
    });
  }
}

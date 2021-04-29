import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/assets.dart';
import 'package:nmobile/utils/format.dart';

import '../label.dart';

class WalletItem extends StatefulWidget {
  final WalletSchema schema;
  final String type;
  final GestureTapCallback onTap;
  final Widget leading;

  WalletItem({this.schema, this.type, this.onTap, this.leading});

  @override
  _WalletItemState createState() => _WalletItemState();
}

class _WalletItemState extends State<WalletItem> {
  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    SkinTheme theme = application.theme;
    if (widget.type == WalletType.nkn) {
      return Flex(
        direction: Axis.horizontal,
        children: [
          Expanded(
            flex: 0,
            child: Hero(
              tag: 'avatar:${'widget.schema.address'}',
              child: Padding(
                padding: const EdgeInsets.only(right: 20, top: 16, bottom: 16),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.logoBackground,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: SvgPicture.asset('assets/logo.svg', color: theme.nknLogoColor),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Label('wallet.name', type: LabelType.h3),
                Label(
                  nknFormat(123.123, decimalDigits: 4, symbol: 'NKN'),
                  type: LabelType.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(9)), color: theme.successColor.withAlpha(25)),
                  child: Text(
                    _localizations.mainnet,
                    style: TextStyle(color: theme.successColor, fontSize: 10, fontWeight: FontWeight.bold, height: 1.2),
                  ),
                )
              ],
            ),
          ),
          widget.leading != null ? widget.leading : Container(),
        ],
      );
    } else if (widget.type == WalletType.eth) {
      return Flex(
        direction: Axis.horizontal,
        children: [
          Hero(
            tag: 'avatar:${'widget.schema.address'}',
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 20, top: 16, bottom: 16),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.logoBackground,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: SvgPicture.asset('assets/logo.svg',
                        color: theme.nknLogoColor),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 34,
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: theme.ethLogoBackground, shape: BoxShape.circle),
                    child: SvgPicture.asset('assets/ethereum-logo.svg'),
                  ),
                )
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Label('wallet.name', type: LabelType.h3),
                Label(
                  nknFormat(123.123, decimalDigits: 4, symbol: 'NKN'),
                  type: LabelType.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(9)), color: theme.successColor.withAlpha(25)),
                  child: Text(
                    _localizations.mainnet,
                    style: TextStyle(color: theme.successColor, fontSize: 10, fontWeight: FontWeight.bold, height: 1.2),
                  ),
                )
              ],
            ),
          ),
          widget.leading != null ? widget.leading : Container(),
        ],
      );
    }
  }
}

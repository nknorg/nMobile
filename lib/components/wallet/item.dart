import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/wallet/avatar.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/format.dart';

class WalletItem extends StatefulWidget {
  final WalletSchema schema;
  final String type;
  final GestureTapCallback onTap;
  final Widget tail;

  WalletItem({
    this.schema,
    this.type,
    this.onTap,
    this.tail,
  });

  @override
  _WalletItemState createState() => _WalletItemState();
}

class _WalletItemState extends State<WalletItem> {
  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    SkinTheme theme = application.theme;

    if (widget.type == WalletType.nkn) {
      return Row(
        children: [
          Expanded(
            flex: 0,
            child: Hero(
              tag: 'avatar:${widget?.schema?.address}',
              child: WalletAvatar(
                width: 48,
                height: 48,
                walletType: WalletType.nkn,
                padding: EdgeInsets.only(right: 20, top: 16, bottom: 16),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Label(
                  widget.schema?.name ?? "",
                  type: LabelType.h3,
                ),
                Label(
                  nknFormat(widget.schema?.balance ?? 0, decimalDigits: 4, symbol: 'NKN'),
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
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(9)),
                    color: theme.successColor.withAlpha(25),
                  ),
                  child: Text(
                    _localizations.mainnet,
                    style: TextStyle(
                      color: theme.successColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                )
              ],
            ),
          ),
          widget.tail ?? Container(),
        ],
      );
    } else if (widget.type == WalletType.eth) {
      return Row(
        children: [
          Hero(
            tag: 'avatar:${widget?.schema?.address}',
            child: WalletAvatar(
              width: 48,
              height: 48,
              walletType: WalletType.eth,
              padding: EdgeInsets.only(right: 20, top: 16, bottom: 16),
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Label(
                  widget.schema?.name ?? "",
                  type: LabelType.h3,
                ),
                Label(
                  nknFormat(widget.schema?.balance ?? 0, decimalDigits: 4, symbol: 'NKN'),
                  type: LabelType.bodySmall,
                ),
              ],
            ),
          ),
          // TODO:GG eth adapt
          Expanded(
            flex: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(9)),
                    color: theme.successColor.withAlpha(25),
                  ),
                  child: Text(
                    _localizations.ERC_20,
                    style: TextStyle(
                      color: theme.successColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                )
              ],
            ),
          ),
          widget.tail ?? Container(),
        ],
      );
    }
    return SizedBox.shrink();
  }
}

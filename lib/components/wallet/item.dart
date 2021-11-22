import 'package:flutter/material.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/wallet/avatar.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/format.dart';

class WalletItem extends StatelessWidget {
  final String walletType;
  final WalletSchema wallet;
  final GestureTapCallback? onTap;
  final bool onTapWave;
  final Color? bgColor;
  final BorderRadius? radius;
  final EdgeInsetsGeometry? padding;
  final Widget? tail;

  WalletItem({
    required this.walletType,
    required this.wallet,
    this.onTap,
    this.onTapWave = true,
    this.bgColor,
    this.radius,
    this.padding,
    this.tail,
  });

  @override
  Widget build(BuildContext context) {
    return this.onTap != null
        ? this.onTapWave
            ? Material(
                color: this.bgColor,
                elevation: 0,
                borderRadius: this.radius,
                child: InkWell(
                  borderRadius: this.radius,
                  onTap: this.onTap,
                  child: _getItemBody(context),
                ),
              )
            : InkWell(
                borderRadius: this.radius,
                onTap: this.onTap,
                child: _getItemBody(context),
              )
        : _getItemBody(context);
  }

  Widget _getItemBody(BuildContext context) {
    SkinTheme theme = application.theme;

    return Container(
      decoration: BoxDecoration(
        color: (this.onTap != null && this.onTapWave) ? null : this.bgColor,
        borderRadius: this.radius,
      ),
      padding: this.padding ?? EdgeInsets.only(left: 16, right: 16),
      child: Row(
        children: [
          WalletAvatar(
            width: 48,
            height: 48,
            walletType: this.walletType,
            padding: EdgeInsets.only(right: 20, top: 16, bottom: 16),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Label(
                  this.wallet.name ?? "",
                  type: LabelType.h3,
                ),
                Label(
                  nknFormat(this.wallet.balance, decimalDigits: 4, symbol: 'NKN'),
                  type: LabelType.bodySmall,
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(9)),
                  color: this.walletType == WalletType.eth ? theme.ethLogoBackground.withAlpha(25) : theme.successColor.withAlpha(25),
                ),
                child: Text(
                  this.walletType == WalletType.eth ? Global.locale((s) => s.ERC_20, ctx: context) : Global.locale((s) => s.mainnet, ctx: context),
                  style: TextStyle(
                    color: this.walletType == WalletType.eth ? theme.ethLogoBackground : theme.successColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
              this.walletType == WalletType.eth
                  ? Padding(
                      padding: EdgeInsets.only(right: 4, top: 4),
                      child: Label(
                        nknFormat(this.wallet.balanceEth, symbol: 'ETH'),
                        type: LabelType.bodySmall,
                      ),
                    )
                  : SizedBox.shrink(),
            ],
          ),
          this.tail ?? Container(),
        ],
      ),
    );
  }
}

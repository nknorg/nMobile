import 'package:flutter/widgets.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/asset.dart';

class WalletAvatar extends StatelessWidget {
  final double width;
  final double height;
  final String walletType;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool ethBig;
  final double ethWidth;
  final double ethHeight;
  final double ethTop;
  final double ethRight;

  WalletAvatar({
    this.width = 48,
    this.height = 48,
    this.walletType = WalletType.nkn,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    this.radius = 8,
    this.ethBig = false,
    this.ethWidth = 20,
    this.ethHeight = 20,
    this.ethTop = 12,
    this.ethRight = 15,
  });

  @override
  Widget build(BuildContext context) {
    bool canEtgBig = this.walletType == WalletType.eth && this.ethBig;
    return Stack(
      children: [
        Padding(
          padding: this.padding,
          child: Container(
            width: this.width,
            height: this.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: application.theme.logoBackground,
              borderRadius: BorderRadius.all(Radius.circular(this.radius)),
            ),
            child: Asset.svg(
              canEtgBig ? 'ethereum-logo' : 'logo',
              color: canEtgBig ? application.theme.ethLogoColor : application.theme.nknLogoColor,
              width: canEtgBig ? this.ethWidth : null,
              height: canEtgBig ? this.ethHeight : null,
            ),
          ),
        ),
        this.walletType == WalletType.eth && !this.ethBig
            ? Positioned(
                top: this.ethTop,
                right: this.ethRight,
                child: Container(
                  width: this.ethWidth,
                  height: this.ethHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: application.theme.ethLogoBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Asset.svg('ethereum-logo'),
                ),
              )
            : SizedBox.shrink(),
      ],
    );
  }
}

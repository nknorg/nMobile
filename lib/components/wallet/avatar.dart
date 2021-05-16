import 'package:flutter/widgets.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/utils/assets.dart';

class WalletAvatar extends StatefulWidget {
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
  _WalletAvatarState createState() => _WalletAvatarState();
}

class _WalletAvatarState extends State<WalletAvatar> {
  @override
  Widget build(BuildContext context) {
    bool canEtgBig = widget.walletType == WalletType.eth && widget.ethBig;
    return Stack(
      children: [
        Padding(
          padding: widget.padding,
          child: Container(
            width: widget.width,
            height: widget.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: application.theme.logoBackground,
              borderRadius: BorderRadius.all(Radius.circular(widget.radius)),
            ),
            child: Asset.svg(
              canEtgBig ? 'ethereum-logo' : 'logo',
              color: canEtgBig ? application.theme.ethLogoColor : application.theme.nknLogoColor,
              width: canEtgBig ? widget.ethWidth : null,
              height: canEtgBig ? widget.ethHeight : null,
            ),
          ),
        ),
        widget.walletType == WalletType.eth && !widget.ethBig
            ? Positioned(
                top: widget.ethTop,
                right: widget.ethRight,
                child: Container(
                  width: widget.ethWidth,
                  height: widget.ethHeight,
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

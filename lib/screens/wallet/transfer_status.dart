import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/utils/extensions.dart';

@deprecated
class TransferStatusPopup extends PopupRoute {
  TransferStatusPopup.show(BuildContext context) {
    Navigator.push(context, this);
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Container(
              width: double.infinity, height: 143, color: Colours.green_06),
          Positioned(
            left: 24,
            top: 46,
            right: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SvgPicture.asset('assets/wallet/dui_gou_yuan_quan.svg',
                        color: Colours.white)
                    .pad(t: 16),
                _buildText(context),
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  child: SvgPicture.asset('assets/icons/x_cha.svg',
                          color: Colours.white, width: 12, height: 12)
                      .center
                      .sized(w: 48, h: 48),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildText(BuildContext context) {
    return Expanded(
      flex: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            NL10ns.of(context).transfer_initiated,
            style: TextStyle(
                fontSize: DefaultTheme.h4FontSize,
                fontWeight: FontWeight.bold,
                color: Colours.white),
          ).pad(l: 16, t: 14),
          Text(
            NL10ns.of(context).transfer_initiated_desc,
            style: TextStyle(
                fontSize: DefaultTheme.bodySmallFontSize, color: Colours.white),
          ).pad(l: 16, t: 12),
        ],
      ),
    );
  }

  @override
  Color get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => null;

  @override
  Duration get transitionDuration => Duration(milliseconds: 30);
}

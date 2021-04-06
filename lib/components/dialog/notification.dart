import 'package:bot_toast/bot_toast.dart';
import 'package:bot_toast/src/toast_widget/animation.dart';
import 'package:bot_toast/src/toast_widget/notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/utils/extensions.dart';

class NotificationDialog extends StatefulWidget {
  @override
  _NotificationDialogState createState() => _NotificationDialogState();
  BuildContext context;

  NotificationDialog.of(this.context);

  Color color;
  Widget icon;
  String title;
  String content;
  double height;
  CancelFunc cancelFunc;

  CancelFunc show({
    Color color,
    Widget icon,
    String title,
    String content,
    double height = 143,
  }) {
    this.color = color;
    this.icon = icon;
    this.title = title;
    this.content = content;
    this.height = height;
    return BotToast.showAnimationWidget(
        crossPage: true,
        allowClick: true,
        clickClose: false,
        ignoreContentClick: false,
        onlyOne: true,
        duration: const Duration(seconds: 6),
        animationDuration: const Duration(milliseconds: 256),
        wrapToastAnimation: (controller, cancel, child) {
          final anim = notificationAnimation(controller, cancel, child);
          if (anim != null) {
            child = anim;
          }
          child = Align(alignment: Alignment.topCenter, child: child);
          return child;
        },
        toastBuilder: (CancelFunc cancelFunc) {
          this.cancelFunc = cancelFunc;
          return NotificationToast(
            child: this,
            dismissDirections: const [
              DismissDirection.horizontal,
              DismissDirection.up
            ],
            slideOffFunc: cancelFunc,
          );
        },
        groupKey: BotToast.notificationKey);
  }
}

class _NotificationDialogState extends State<NotificationDialog> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.topCenter,
      padding: EdgeInsets.all(0),
      height: 140,
      decoration:
          BoxDecoration(color: widget.color ?? DefaultTheme.primaryColor),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            (widget.icon ??
                    SvgPicture.asset('assets/wallet/dui_gou_yuan_quan.svg',
                        color: Colours.white))
                .pad(t: 16),
            _buildText(context),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              child: SvgPicture.asset('assets/icons/x_cha.svg',
                      color: Colours.white, width: 12, height: 12)
                  .center
                  .sized(w: 48, h: 48),
              onTap: widget.cancelFunc,
            ),
          ],
        ).pad(l: 24, t: 3, r: 6, b: 0),
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
            widget.title,
            style: TextStyle(
                fontSize: DefaultTheme.h4FontSize,
                fontWeight: FontWeight.bold,
                color: Colours.white),
          ).pad(l: 16, t: 14),
          Text(
            widget.content,
            style: TextStyle(
                fontSize: DefaultTheme.bodySmallFontSize, color: Colours.white),
          ).pad(l: 16, t: 6),
        ],
      ),
    );
  }
}

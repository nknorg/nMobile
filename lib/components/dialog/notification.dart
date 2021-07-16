import 'package:bot_toast/bot_toast.dart';
import 'package:bot_toast/src/toast_widget/animation.dart';
import 'package:bot_toast/src/toast_widget/notification.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/asset.dart';

class NotificationDialog extends StatelessWidget {
  BuildContext context;

  NotificationDialog.of(this.context);

  String? title;
  String? content;
  Widget? headIcon;
  Color? bgColor;
  CancelFunc? cancelFunc;

  CancelFunc show({
    String? title,
    String? content,
    Widget? headIcon,
    Color? bgColor,
  }) {
    this.bgColor = bgColor;
    this.headIcon = headIcon;
    this.title = title;
    this.content = content;
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
          dismissDirections: const [DismissDirection.horizontal, DismissDirection.up],
          slideOffFunc: cancelFunc,
        );
      },
      groupKey: BotToast.notificationKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(color: this.bgColor ?? application.theme.primaryColor),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: (this.headIcon ?? Asset.iconSvg('check', color: Colors.white)),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: Text(
                          this.title ?? "",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 10,
                        ),
                      ), //.pad(l: 16, t: 14),
                      Padding(
                        padding: const EdgeInsets.only(left: 8, right: 8, bottom: 18),
                        child: Text(
                          this.content ?? "",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          maxLines: 10,
                        ),
                      ), //.pad(l: 16, t: 6),
                    ],
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    child: Asset.iconSvg('close', color: Colors.white, width: 14),
                    onTap: this.cancelFunc,
                  ),
                ),
              ],
            ), // .pad(l: 24, t: 3, r: 6, b: 0),
          ),
        ),
      ],
    );
  }
}

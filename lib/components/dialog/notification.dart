import 'package:bot_toast/bot_toast.dart';
import 'package:bot_toast/src/toast_widget/animation.dart';
import 'package:bot_toast/src/toast_widget/notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/consts/theme.dart';

class NotificationDialog extends StatefulWidget {
  @override
  _NotificationDialogState createState() => _NotificationDialogState();

  BuildContext context;
  NotificationDialog();

  NotificationDialog.of(this.context);

  Widget child;
  Widget icon;
  Color color;
  Widget title;
  Widget content;
  double height;
  CancelFunc cancelFunc;

  CancelFunc show({
    Widget child,
    Widget icon,
    Color color,
    Widget title,
    Widget content,
    double height,
  }) {
    this.child = child;
    this.icon = icon;
    this.color = color;
    this.title = title;
    this.content = content;
    this.height = height;
    return BotToast.showAnimationWidget(
        crossPage: true,
        allowClick: true,
        clickClose: false,
        ignoreContentClick: false,
        onlyOne: true,
        duration: const Duration(seconds: 5),
        animationDuration: const Duration(milliseconds: 256),
        wrapToastAnimation: (controller, cancel, child) {
          if (notificationAnimation != null) {
            child = notificationAnimation(controller, cancel, child);
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
      height: widget.height,
      constraints: BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(color: widget.color ?? DefaultTheme.notificationBackgroundColor),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
          child: Flex(
            direction: Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 0,
                child: widget.icon != null
                    ? Padding(
                        padding: const EdgeInsets.only(right: 18, top: 0),
                        child: widget.icon,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(0),
                      ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        widget.title,
                        Button(
                          icon: true,
                          padding: const EdgeInsets.all(0),
                          size: 30,
                          child: SvgPicture.asset(
                            'assets/icons/close.svg',
                            width: 16,
                            color: DefaultTheme.backgroundLightColor,
                          ),
                          onPressed: () => widget.cancelFunc(),
                        )
                      ],
                    ),
                    widget.content != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: widget.content,
                          )
                        : Padding(
                            padding: const EdgeInsets.all(0),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

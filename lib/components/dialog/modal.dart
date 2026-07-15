import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/button/button_icon.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/utils/asset.dart';

class ModalDialog extends StatelessWidget {
  BuildContext context;

  ModalDialog.of(this.context);

  String? title;
  Widget? titleWidget;
  String? content;
  Widget? contentWidget;
  bool hasCloseIcon = false;
  bool hasCloseButton = true;
  double? height;
  List<Widget>? actions;

  close() {
    if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
  }

  show({
    String? title,
    Widget? titleWidget,
    String? content,
    Widget? contentWidget,
    bool hasCloseIcon = false,
    bool hasCloseButton = true,
    double? height,
    List<Widget>? actions,
    bool barrierDismissible = true,
  }) {
    this.title = title;
    this.titleWidget = titleWidget;
    this.content = content;
    this.contentWidget = contentWidget;
    this.hasCloseIcon = hasCloseIcon;
    this.hasCloseButton = hasCloseButton;
    this.height = height;
    this.actions = actions ?? [];
    return showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) {
        Widget dialogWidget = Container(
          alignment: Alignment.center,
          child: this,
        );
        
        if (!barrierDismissible) {
          dialogWidget = PopScope(
            canPop: false,
            child: dialogWidget,
          );
        }
        
        return dialogWidget;
      },
    );
  }

  confirm({
    String? title,
    Widget? titleWidget,
    String? content,
    Widget? contentWidget,
    bool hasCloseIcon = false,
    bool hasCloseButton = false,
    double? height,
    Widget? agree,
    Widget? reject,
  }) {
    this.title = title;
    this.titleWidget = titleWidget;
    this.content = content;
    this.contentWidget = contentWidget;
    this.hasCloseIcon = hasCloseIcon;
    this.hasCloseButton = hasCloseButton;
    this.height = height;
    this.actions = <Widget>[];
    if (agree != null) this.actions?.add(agree);
    if (reject != null) this.actions?.add(reject);
    return showDialog(
      context: context,
      builder: (ctx) {
        return Container(
          alignment: Alignment.center,
          child: this,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> actions = List.of(this.actions ?? []);

    if (this.hasCloseButton) {
      actions.add(Button(
        backgroundColor: application.theme.backgroundLightColor,
        fontColor: application.theme.fontColor2,
        text: Settings.locale((s) => s.close, ctx: context),
        width: double.infinity,
        onPressed: () => this.close(),
      ));
    }

    return Material(
      borderRadius: BorderRadius.all(Radius.circular(20)),
      color: application.theme.backgroundLightColor,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: Stack(
        children: [
          Container(
            width: Settings.screenWidth() - 40,
            height: this.height,
            constraints: BoxConstraints(
              minHeight: 150,
              maxHeight: Settings.screenHeight() - 180,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // title
                  Padding(
                    padding: EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 36),
                    child: this.titleWidget ??
                        Label(
                          this.title ?? Settings.locale((s) => s.warning, ctx: context),
                          type: LabelType.h2,
                          maxLines: 5,
                        ),
                  ),
                  // content
                  Container(
                    padding: EdgeInsets.only(left: 24, right: 24, bottom: 24),
                    child: this.contentWidget ??
                        Label(
                          this.content ?? "",
                          type: LabelType.bodyRegular,
                          maxLines: 100,
                        ),
                  ),
                  // actions
                  Padding(
                    padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
                    child: Column(
                      children: actions,
                    ),
                  ),
                ],
              ),
            ),
          ),
          this.hasCloseIcon
              ? Positioned(
                  right: 0,
                  top: 0,
                  child: SizedBox(
                    height: 55,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: ButtonIcon(
                        width: 50,
                        height: 50,
                        icon: Asset.iconSvg('close', width: 16),
                        onPressed: () => this.close(),
                      ),
                    ),
                  ),
                )
              : SizedBox.shrink(),
        ],
      ),
    );
  }
}

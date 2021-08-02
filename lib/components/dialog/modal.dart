import 'package:flutter/material.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/button/button_icon.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
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
    Navigator.pop(this.context);
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
      // barrierDismissible: false,
      builder: (ctx) {
        return Container(
          alignment: Alignment.center,
          child: this,
        );
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
    S _localizations = S.of(context);
    List<Widget> actions = List.of(this.actions ?? []);

    if (this.hasCloseButton) {
      actions.add(Button(
        backgroundColor: application.theme.backgroundLightColor,
        fontColor: application.theme.fontColor2,
        text: _localizations.close,
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
            width: Global.screenWidth() - 40,
            height: this.height,
            constraints: BoxConstraints(
              minHeight: 150,
              maxHeight: Global.screenHeight() - 180,
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
                          this.title ?? _localizations.warning,
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

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/button/button_icon.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/utils/assets.dart';

class ModalDialog extends StatefulWidget {
  @override
  _ModalDialogState createState() => _ModalDialogState();

  BuildContext context;

  ModalDialog();

  ModalDialog.of(this.context);

  String title;
  Widget titleWidget;
  String content;
  Widget contentWidget;
  bool hasCloseIcon;
  bool hasCloseButton;
  double height;
  List<Widget> actions;

  close() {
    Navigator.of(context).pop();
  }

  show({
    String title,
    Widget titleWidget,
    String content,
    Widget contentWidget,
    bool hasCloseIcon = false,
    bool hasCloseButton = true,
    double height,
    List<Widget> actions,
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
      context: context, //      barrierDismissible: false,
      builder: (ctx) {
        return Container(
          alignment: Alignment.center,
          child: this,
        );
      },
    );
  }

  confirm({
    String title,
    Widget titleWidget,
    String content,
    Widget contentWidget,
    bool hasCloseIcon = true,
    bool hasCloseButton = false,
    double height,
    Widget agree,
    Widget reject,
  }) {
    this.title = title;
    this.titleWidget = titleWidget;
    this.content = content;
    this.contentWidget = contentWidget;
    this.hasCloseIcon = hasCloseIcon;
    this.hasCloseButton = hasCloseButton;
    this.height = height;
    this.actions = <Widget>[agree, reject];
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
}

class _ModalDialogState extends State<ModalDialog> {
  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    List<Widget> actions = List.of(widget.actions);

    if (widget.hasCloseButton) {
      actions.add(Button(
        backgroundColor: application.theme.backgroundLightColor,
        fontColor: application.theme.fontColor2,
        text: _localizations.close,
        width: double.infinity,
        onPressed: () => widget.close(),
      ));
    }

    return Material(
      borderRadius: BorderRadius.all(Radius.circular(20)),
      color: application.theme.backgroundLightColor,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: Stack(
        children: [
          Container(
            width: MediaQuery.of(context).size.width - 40,
            height: widget.height,
            constraints: BoxConstraints(
              minHeight: 150,
              maxHeight: MediaQuery.of(context).size.height - 180,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // title
                  Padding(
                    padding: EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 36),
                    child: widget.titleWidget ??
                        Label(
                          widget.title ?? _localizations.warning,
                          type: LabelType.h2,
                          maxLines: 5,
                        ),
                  ),
                  // content
                  Container(
                    padding: EdgeInsets.only(left: 24, right: 24, bottom: 24),
                    child: widget.contentWidget ??
                        Label(
                          widget.content ?? "",
                          type: LabelType.bodyRegular,
                          maxLines: 100,
                        ),
                  ),
                  // actions
                  Expanded(
                    flex: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
                      child: Column(
                        children: actions,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          widget.hasCloseIcon
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
                        onPressed: () => widget.close(),
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

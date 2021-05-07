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

  Widget title;
  Widget content;
  List<Widget> actions;
  double height;
  bool hasCloseButton;

  show({
    Widget title,
    Widget close,
    Widget content,
    List<Widget> actions,
    double height = 300,
    bool hasCloseButton = true,
  }) {
    this.title = title;
    this.content = content;
    this.actions = actions ?? [];
    this.height = height;
    this.hasCloseButton = hasCloseButton;
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

  close() {
    Navigator.of(context).pop();
  }

  confirm({
    Widget title,
    Widget content,
    Widget agree,
    Widget reject,
    double height = 300,
    bool hasCloseButton = false,
  }) {
    this.title = title;
    this.content = content;
    this.actions = <Widget>[
      agree,
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: reject,
      )
    ];
    this.height = height;
    this.hasCloseButton = hasCloseButton;
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
  void dispose() {
    super.dispose();
  }

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
              minHeight: 200,
              maxHeight: MediaQuery.of(context).size.height - 180,
            ),
            child: Flex(
              direction: Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 1,
                  child: Container(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24, right: 24),
                      child: Flex(
                        direction: Axis.vertical,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            flex: 0,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 24, top: 24),
                              child: widget.title ??
                                  Label(
                                    _localizations.warning,
                                    type: LabelType.h2,
                                  ),
                            ),
                          ),
                          Expanded(flex: 1, child: widget.content ?? Label(''))
                        ],
                      ),
                    ),
                  ),
                ),
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
          Positioned(
            right: 0,
            top: 0,
            child: SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    ButtonIcon(
                      padding: const EdgeInsets.all(0),
                      width: 50,
                      height: 50,
                      icon: assetIcon('close', width: 16),
                      onPressed: () => widget.close(),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

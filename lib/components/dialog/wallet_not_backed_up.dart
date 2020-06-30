import 'package:flutter/material.dart';
import 'package:nmobile/components/ButtonIcon.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';

class WalletNotBackedUpDialog extends StatefulWidget {
  @override
  _WalletNotBackedUpDialogState createState() => _WalletNotBackedUpDialogState();
  final BuildContext _context;
  VoidCallback _callback;

  WalletNotBackedUpDialog.of(this._context);

  show(VoidCallback callback) {
    this._callback = callback;
    return showDialog(
      context: _context,
      barrierDismissible: false,
      builder: (ctx) {
        return Container(
          alignment: Alignment.center,
          child: this,
        );
      },
    );
  }

  close() {
    Navigator.of(_context).pop();
  }
}

class _WalletNotBackedUpDialogState extends State<WalletNotBackedUpDialog> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.all(Radius.circular(20)),
      color: DefaultTheme.backgroundLightColor,
      child: Container(
        width: MediaQuery.of(context).size.width - 20,
        height: 400,
        constraints: BoxConstraints(minHeight: 200),
        child: Flex(
          direction: Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
                flex: 0,
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  ButtonIcon(
                    padding: 0.pad(t: 6, r: 6),
                    width: 48,
                    height: 48,
                    icon: loadAssetIconsImage('close', width: 16),
                    onPressed: () => widget.close(),
                  )
                ])),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    NMobileLocalizations.of(context).d_not_backed_up_title,
                    style: TextStyle(fontSize: DefaultTheme.h2FontSize, color: Colours.dark_2d, fontWeight: FontWeight.bold),
                    maxLines: 2,
                  ),
                  Text(
                    NMobileLocalizations.of(context).d_not_backed_up_desc,
                    style: TextStyle(fontSize: DefaultTheme.h3FontSize, color: Colours.gray_81),
                  ).pad(t: 16)
                ],
              ).pad(l: 24, r: 24),
            ),
            Expanded(
              flex: 0,
              child: Button(
                  backgroundColor: Colours.blue_0f,
                  fontColor: Colours.white,
                  text: NMobileLocalizations.of(context).go_backup,
                  width: double.infinity,
                  size: 48,
                  onPressed: () {
                    // E/flutter (12613): Tried calling: focusScopeNode
                    // E/flutter (12613): #0      Object.noSuchMethod (dart:core-patch/object_patch.dart:53:5)
                    // E/flutter (12613): #1      Route.didPush.<anonymous closure> (package:flutter/src/widgets/navigator.dart:139:17)
                    // Pay attention to the order of the following two sentences, otherwise the above exception will be thrown.
                    widget.close();
                    widget._callback();
                  }).pad(l: 24, r: 24, b: 48),
            ),
          ],
        ),
      ),
    );
  }
}

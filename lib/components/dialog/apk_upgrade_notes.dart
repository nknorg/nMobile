import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';

typedef OnDownload = void Function(Map jsonMap);
typedef OnIgnore = void Function(int versionCode);

class ApkUpgradeNotesDialog extends StatefulWidget {
  @override
  _ApkUpgradeNotesDialogState createState() => _ApkUpgradeNotesDialogState();
  final BuildContext _context;
  int _versionCode;
  String _title;
  String _notes;
  bool _force;
  Map _jsonMap;
  OnDownload _onDownload;
  OnIgnore _onIgnore;

  ApkUpgradeNotesDialog.of(this._context);

  show(int versionCode, String title, String notes, bool force, Map jsonMap, OnDownload onDownload, OnIgnore onIgnore) {
    this._title = title;
    this._versionCode = versionCode;
    this._notes = notes;
    this._force = force;
    this._jsonMap = jsonMap;
    this._onDownload = onDownload;
    this._onIgnore = onIgnore;
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

class _ApkUpgradeNotesDialogState extends State<ApkUpgradeNotesDialog> {
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
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: Button(
                        icon: true,
                        padding: 0.pad().pad(t: 6, r: 6),
                        size: 48,
                        child: loadAssetIconsImage('close', width: 16),
                        onPressed: () => widget.close()).sized(h: 48).toList)),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget._title != null ? widget._title : NMobileLocalizations.of(context).release_notes,
                    style: TextStyle(fontSize: DefaultTheme.h2FontSize, color: Colours.dark_2d, fontWeight: FontWeight.bold),
                    maxLines: 2,
                  ),
                  Expanded(
                    flex: 1,
                    child: ListView(
                      shrinkWrap: true,
                      children: Text(
                        widget._notes,
                        style: TextStyle(fontSize: DefaultTheme.h3FontSize, color: Colours.gray_81),
                      ).toList,
                    ).pad(t: 12, b: 12),
                  )
                ],
              ).pad(l: 24, r: 24),
            ),
            Expanded(
              flex: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  widget._force
                      ? Space.empty
                      : Expanded(
                          flex: 0,
                          child: FlatButton(
                            color: Colors.transparent,
                            textColor: Colours.pink_f8,
                            child: Text(
                              NMobileLocalizations.of(context).ignore,
                              style: TextStyle(fontStyle: FontStyle.italic, decoration: TextDecoration.underline, decorationColor: Colours.pink_f8),
                            ),
                            padding: 0.pad(l: 24, r: 24),
                            onPressed: () {
                              widget.close();
                              widget._onIgnore(widget._versionCode);
                            },
                            shape: StadiumBorder(side: BorderSide(style: BorderStyle.none)),
                          ).sized(h: 48).pad(r: 12),
                        ),
                  Expanded(
                    flex: 1,
                    child: FlatButton(
                            color: Colours.blue_0f,
                            textColor: Colours.white,
                            child: Text(NMobileLocalizations.of(context).download_now),
                            padding: 0.pad(l: 24, r: 24),
                            onPressed: () {
                              widget.close();
                              widget._onDownload(widget._jsonMap);
                            },
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)))
                        .sized(h: 48),
                  )
                ],
              ).pad(l: 24, r: 24, b: 36),
            ),
          ],
        ),
      ),
    );
  }
}

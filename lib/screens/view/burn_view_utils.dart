import 'package:flutter/material.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:path/path.dart';

class BurnViewUtil {
  Context context;
  static List _burnTextArray = null;
  static int currentIndex = 0;

  static showBurnViewDialog(context) {
    if (_burnTextArray == null) {
      _burnTextArray = <String>[
        NMobileLocalizations.of(context).burn_5_seconds,
        NMobileLocalizations.of(context).burn_10_seconds,
        NMobileLocalizations.of(context).burn_30_seconds,
        NMobileLocalizations.of(context).burn_1_minute,
        NMobileLocalizations.of(context).burn_5_minutes,
        NMobileLocalizations.of(context).burn_10_minutes,
        NMobileLocalizations.of(context).burn_30_minutes,
        NMobileLocalizations.of(context).burn_1_hour,
        NMobileLocalizations.of(context).burn_1_day,
      ];
    }

    showDialog<Null>(
      context: context,
      builder: (BuildContext context) {
        return BurnViewPage(
          burnTextArray: _burnTextArray,
          currentIndex: currentIndex,
        );
      },
    );
  }
}

class BurnViewPage extends StatefulWidget {
  static final String routeName = "BurnViewPage";
  final List burnTextArray;
  final int currentIndex;

  BurnViewPage({Key key, this.burnTextArray, this.currentIndex}) : super(key: key);

  @override
  BurnViewPageState createState() => new BurnViewPageState();
}

class BurnViewPageState extends State<BurnViewPage> {
  List burnTextArray = [];
  int currentIndex = -1;

  @override
  void initState() {
    super.initState();
    burnTextArray = widget.burnTextArray;
    currentIndex = widget.currentIndex;
  }

  getItemView(List burnTextArray, context) {
    List<Widget> views = [];
    views.add(SimpleDialogOption(
      child: Row(
        children: <Widget>[
          Text(NMobileLocalizations.of(context).close),
          Spacer(),
          currentIndex == -1
              ? Icon(
                  Icons.check,
                  color: Colors.red,
                  size: 16,
                )
              : Container()
        ],
      ),
      onPressed: () {
        setState(() {
          currentIndex = -1;
        });
      },
    ));
    for (int i = 0; i < burnTextArray.length; i++) {
      var content = burnTextArray[i];
      views.add(SimpleDialogOption(
        child: Row(
          children: <Widget>[
            Text(content),
            Spacer(),
            i == currentIndex
                ? Icon(
                    Icons.check,
                    color: Colors.red,
                    size: 16,
                  )
                : Container()
          ],
        ),
        onPressed: () {
          setState(() {
            currentIndex = i;
          });
        },
      ));
    }
    views.add(SimpleDialogOption(child: Text('对话接受和发送的消息将于${burnTextArray[currentIndex]}后消失。')));
    views.add(Row(
      children: <Widget>[
        Spacer(),
        SimpleDialogOption(
          child: Label(
            NMobileLocalizations.of(context).cancel,
            type: LabelType.bodyRegular,
            color: DefaultTheme.fontColor1,
            textAlign: TextAlign.start,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        SimpleDialogOption(
          child: Label(
            NMobileLocalizations.of(context).ok,
            type: LabelType.bodyRegular,
            color: DefaultTheme.fontColor1,
            textAlign: TextAlign.start,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ],
    ));
    return views;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        title: Text('选择'),
        children: getItemView(burnTextArray, context),
      ),
    );
  }
}

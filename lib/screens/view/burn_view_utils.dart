import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/entity/contact.dart';
import 'package:nmobile/model/entity/message.dart';
import 'package:nmobile/model/entity/options.dart';
import 'package:nmobile/utils/extensions.dart';

class BurnViewUtil {
  static List<Duration> burnValueArray = [
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 6),
    Duration(hours: 12),
    Duration(days: 1),
    Duration(days: 7),
  ];

  static List<String> burnTextArray(BuildContext context) {
    return [
      NL10ns.of(context).burn_5_seconds,
      NL10ns.of(context).burn_10_seconds,
      NL10ns.of(context).burn_30_seconds,
      NL10ns.of(context).burn_1_minute,
      NL10ns.of(context).burn_5_minutes,
      NL10ns.of(context).burn_10_minutes,
      NL10ns.of(context).burn_30_minutes,
      NL10ns.of(context).burn_1_hour,
      NL10ns.of(context).burn_6_hour,
      NL10ns.of(context).burn_12_hour,
      NL10ns.of(context).burn_1_day,
      NL10ns.of(context).burn_1_week,
    ];
  }

  static String getStringFromSeconds(context, int seconds) {
    int currentIndex = -1;
    for (int index = 0; index < burnValueArray.length; index++) {
      Duration duration = burnValueArray[index];
      if (seconds == duration.inSeconds) {
        currentIndex = index;
        break;
      }
    }
    if (currentIndex == -1) {
      return '';
    } else {
      return burnTextArray(context)[currentIndex];
    }
  }

  static showBurnViewDialog(context, contact, chatBloc) async {
    int currentIndex = -1;
    var _sourceOptions =
        OptionsSchema(deleteAfterSeconds: contact?.options?.deleteAfterSeconds);
    if (_sourceOptions.deleteAfterSeconds != null &&
        _sourceOptions.deleteAfterSeconds != -1) {
      for (int index = 0; index < burnValueArray.length; index++) {
        Duration duration = burnValueArray[index];
        if (_sourceOptions.deleteAfterSeconds == duration.inSeconds) {
          currentIndex = index;
          break;
        }
      }
    }

    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return BurnViewPage(
          currentIndex: currentIndex,
          contact: contact,
          chatBloc: chatBloc,
        );
      },
    );
  }
}

class BurnViewPage extends StatefulWidget {
  final int currentIndex;
  final ContactSchema contact;
  final ChatBloc chatBloc;

  BurnViewPage({Key key, this.currentIndex, this.contact, this.chatBloc})
      : super(key: key);

  @override
  BurnViewPageState createState() => new BurnViewPageState();
}

class BurnViewPageState extends State<BurnViewPage> {
  int currentIndex = -1;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SimpleDialog(
        titlePadding: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
        contentPadding: EdgeInsets.fromLTRB(0.0, 12.0, 0.0, 12.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        title: Text(NL10ns.of(context).select),
        children: getItemView(BurnViewUtil.burnTextArray(context), context),
      ),
    );
  }

  getItemView(List burnTextArray, context) {
    List<Widget> views = [];
    List<Widget> items = [];
    items.add(SimpleDialogOption(
      child: Container(
        width: double.maxFinite,
        height: 20,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(NL10ns.of(context).off,
                style: TextStyle(fontWeight: FontWeight.w500)),
            Spacer(),
            currentIndex == -1
                ? Icon(Icons.check, color: Colors.red, size: 16)
                : Space.empty
          ],
        ),
      ),
      onPressed: () {
        setState(() {
          currentIndex = -1;
        });
      },
    ));
    for (int i = 0; i < burnTextArray.length; i++) {
      var content = burnTextArray[i];
      items.add(SimpleDialogOption(
        child: Container(
          height: 20,
          child: Row(
            children: [
              Text(content),
              Spacer(),
              i == currentIndex
                  ? Icon(Icons.check, color: Colors.red, size: 16)
                  : Space.empty
            ],
          ),
        ),
        onPressed: () {
          setState(() {
            currentIndex = i;
          });
        },
      ));
    }
    views.add(SingleChildScrollView(
      child: Column(
        children: items,
      ),
    ));

    views.add(
      SimpleDialogOption(
        child: Container(
          height: 56,
          child: Text(currentIndex < 0
              ? NL10ns.of(context).burn_after_reading_desc
              : NL10ns.of(context).burn_after_reading_desc_disappear(
                  burnTextArray[currentIndex],
                )),
        ),
      ),
    );

    views.add(Row(
      children: <Widget>[
        Spacer(),
        SimpleDialogOption(
          child: Label(
            NL10ns.of(context).cancel,
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
            NL10ns.of(context).ok,
            type: LabelType.bodyRegular,
            color: DefaultTheme.fontColor1,
            textAlign: TextAlign.start,
          ),
          onPressed: () async {
            setBurnMessage();
          },
        ),
      ],
    ));
    return views;
  }

  setBurnMessage() async {
    var _burnValue;
    if (currentIndex != -1) {
      _burnValue = BurnViewUtil.burnValueArray[currentIndex].inSeconds;
      await widget.contact.setBurnOptions(_burnValue);
    } else {
      await widget.contact.setBurnOptions(null);
    }
    var sendMsg = MessageSchema.fromSendData(
      from: NKNClientCaller.currentChatId,
      to: widget.contact.clientAddress,
      contentType: ContentType.eventContactOptions,
    );
    sendMsg.burnAfterSeconds = _burnValue;
    sendMsg.contactOptionsType = 0;
    sendMsg.content = sendMsg.toContentOptionData();
    widget.chatBloc.add(SendMessageEvent(sendMsg));
    Navigator.pop(context, _burnValue);
  }
}

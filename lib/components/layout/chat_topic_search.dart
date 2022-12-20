import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/text/form_text.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/helpers/validate.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/popular_channel.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/asset.dart';

class ChatTopicSearchLayout extends BaseStateFulWidget {
  @override
  _CreateGroupDialogState createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends BaseStateFulWidgetState<ChatTopicSearchLayout> {
  GlobalKey _formKey = new GlobalKey<FormState>();
  bool _formValid = false;

  TextEditingController _topicController = TextEditingController();
  bool _privateSelected = false;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
  }

  Future<bool> createOrJoinTopic(String? topicName) async {
    if (topicName == null || topicName.isEmpty) return false;
    if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);

    if (_privateSelected) {
      if (clientCommon.getPublicKey() == null) return false;
      if (Validate.isPrivateTopicOk(topicName)) {
        int index = topicName.lastIndexOf('.');
        String owner = topicName.substring(index + 1);
        if (owner != clientCommon.getPublicKey()) return false;
      } else {
        topicName = '$topicName.${clientCommon.getPublicKey()}';
      }
    }

    double? fee = await BottomDialog.of(Global.appContext).showTransactionSpeedUp();
    if (fee == null) return false;
    Loading.show();
    TopicSchema? _topic = await topicCommon.subscribe(topicName, fetchSubscribers: true, fee: fee);
    Loading.dismiss();

    if (_topic == null) return false;
    ChatMessagesScreen.go(Global.appContext, _topic);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    SkinTheme _theme = application.theme;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onChanged: () {
        _formValid = (_formKey.currentState as FormState).validate();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  SizedBox(width: 20),
                  Label(
                    Global.locale((s) => s.name),
                    type: LabelType.bodyRegular,
                    color: _theme.fontColor1,
                    textAlign: TextAlign.start,
                  ),
                  Spacer(),
                  Row(
                    children: <Widget>[
                      Label(
                        Global.locale((s) => s.private_channel),
                        type: LabelType.bodyRegular,
                        color: _theme.fontColor1,
                      ),
                      CupertinoSwitch(
                        value: _privateSelected,
                        activeColor: _theme.primaryColor,
                        onChanged: (value) async {
                          setState(() {
                            _privateSelected = value;
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(width: 20),
                ],
              ),
              SizedBox(height: 2),
              Container(
                padding: EdgeInsets.only(left: 20, right: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: FormText(
                        controller: _topicController,
                        hintText: Global.locale((s) => s.input_name),
                        validator: Validator.of(context).required(),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 16, top: 16),
                child: Label(
                  Global.locale((s) => s.popular_channels),
                  type: LabelType.h4,
                  textAlign: TextAlign.start,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Expanded(
            child: _getPopularListView(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 18, bottom: 18),
              child: Button(
                width: double.infinity,
                text: Global.locale((s) => s.continue_text),
                onPressed: () {
                  if (_formValid) createOrJoinTopic(_topicController.text);
                },
              ),
            ),
          )
        ],
      ),
    );
  }

  _getPopularListView() {
    double itemHeight = 40;
    List<Widget> list = [];

    for (PopularChannel item in PopularChannel.defaultData()) {
      list.add(InkWell(
        onTap: () {
          createOrJoinTopic(item.topic);
        },
        child: Container(
          width: double.infinity,
          height: itemHeight,
          margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                height: itemHeight,
                width: itemHeight,
                decoration: BoxDecoration(
                  color: item.titleBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Label(
                    item.title,
                    type: LabelType.h4,
                    color: item.titleColor,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Label(
                      item.topic,
                      type: LabelType.bodyRegular,
                      color: application.theme.fontColor1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Label(
                      item.desc,
                      height: 1,
                      type: LabelType.bodySmall,
                    ),
                  ],
                ),
              ),
              Asset.svg(
                'icons/chat',
                width: 24,
                color: application.theme.primaryColor,
              ),
            ],
          ),
        ),
      ));
    }
    return SingleChildScrollView(
      child: Column(
        children: list,
      ),
    );
  }
}

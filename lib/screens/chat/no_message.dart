import 'package:flutter/material.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/popular_channel.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/utils/asset.dart';

import 'messages.dart';

class ChatNoMessageLayout extends BaseStateFulWidget {
  @override
  _ChatNoMessageLayoutState createState() => _ChatNoMessageLayoutState();
}

class _ChatNoMessageLayoutState extends BaseStateFulWidgetState<ChatNoMessageLayout> {
  List<PopularChannel> _populars = PopularChannel.defaultData();

  @override
  void onRefreshArguments() {}

  void addContact() async {
    String? address = await BottomDialog.of(context).showInput(
      title: S.of(context).new_whisper,
      inputTip: S.of(context).send_to,
      inputHint: S.of(context).enter_or_select_a_user_pubkey,
      validator: Validator.of(context).identifierNKN(),
      contactSelect: true,
    );
    if (address?.isNotEmpty == true) {
      var contact = await ContactSchema.createByType(address, ContactType.stranger);
      await contactCommon.add(contact);
      await ChatMessagesScreen.go(context, contact);
    }
  }

  void addTopic(String? topicName) async {
    if (topicName == null || topicName.isEmpty) return;
    Loading.show();
    TopicSchema? _topic = await topicCommon.subscribe(topicName);
    Loading.dismiss();
    ChatMessagesScreen.go(context, _topic);
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);

    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 20),
              Label(
                _localizations.popular_channels,
                type: LabelType.h3,
                textAlign: TextAlign.left,
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            height: 188,
            child: ListView.builder(
              itemCount: _populars.length,
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                return _createPopularItemView(index, _populars.length, _populars[index]);
              },
            ),
          ),
          SizedBox(height: 32),
          Column(
            children: <Widget>[
              Label(
                _localizations.chat_no_messages_title,
                type: LabelType.h2,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Label(
                _localizations.chat_no_messages_desc,
                type: LabelType.bodyRegular,
                textAlign: TextAlign.center,
              )
            ],
          ),
          SizedBox(height: 54),
          Button(
            height: 54,
            padding: const EdgeInsets.only(left: 36, right: 36),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Asset.iconSvg(
                    'pencil',
                    width: 24,
                    color: application.theme.backgroundLightColor,
                  ),
                ),
                Label(
                  _localizations.start_chat,
                  type: LabelType.h2,
                  dark: true,
                ),
              ],
            ),
            onPressed: () {
              addContact();
            },
          ),
        ],
      ),
    );
  }

  Widget _createPopularItemView(int index, int length, PopularChannel model) {
    return UnconstrainedBox(
      child: Container(
        width: 120,
        margin: EdgeInsets.only(
          left: 20,
          right: (index == length - 1) ? 20 : 12,
          top: 8,
          bottom: 8,
        ),
        decoration: BoxDecoration(
          color: application.theme.backgroundColor2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 16),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: model.titleBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Label(
                  model.title,
                  type: LabelType.h3,
                  color: model.titleColor,
                ),
              ),
            ),
            SizedBox(height: 6),
            Label(
              model.subTitle,
              type: LabelType.h4,
            ),
            SizedBox(height: 16),
            Container(
              width: 90,
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              decoration: BoxDecoration(
                color: application.theme.badgeColor,
                borderRadius: BorderRadius.circular(100),
              ),
              child: InkWell(
                onTap: () {
                  // TODO:GG auth
                  // if (TimerAuth.authed) {
                  addTopic(model.topic);
                  // } else {
                  //   widget.timerAuth.onCheckAuthGetPassword(context);
                  // }
                },
                child: Center(
                  child: Text(
                    S.of(context).subscribe,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

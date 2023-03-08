import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/popular_channel.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/utils/asset.dart';

class ChatNoMessageLayout extends BaseStateFulWidget {
  @override
  _ChatNoMessageLayoutState createState() => _ChatNoMessageLayoutState();
}

class _ChatNoMessageLayoutState extends BaseStateFulWidgetState<ChatNoMessageLayout> {
  List<PopularChannel> _populars = PopularChannel.defaultData();

  @override
  void onRefreshArguments() {}

  void addContact() async {
    String? address = await BottomDialog.of(Settings.appContext).showInput(
      title: Settings.locale((s) => s.new_whisper, ctx: context),
      inputTip: Settings.locale((s) => s.send_to, ctx: context),
      inputHint: Settings.locale((s) => s.enter_or_select_a_user_pubkey, ctx: context),
      // validator: Validator.of(context).identifierNKN(),
      contactSelect: true,
    );
    Loading.show();
    ContactSchema? contact = await contactCommon.resolveByAddress(address, canAdd: true);
    Loading.dismiss();
    if (contact != null) await ChatMessagesScreen.go(Settings.appContext, contact);
  }

  void subscribePopularTopic(String? topicName) async {
    if (topicName == null || topicName.isEmpty) return;
    double? fee = await BottomDialog.of(this.context).showTransactionSpeedUp();
    if (fee == null) return;
    Loading.show();
    TopicSchema? _topic = await topicCommon.subscribe(topicName, fetchSubscribers: true, fee: fee);
    Loading.dismiss();
    if (_topic != null) ChatMessagesScreen.go(Settings.appContext, _topic);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 20),
              Label(
                Settings.locale((s) => s.popular_channels, ctx: context),
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
                if (index < 0 || index >= _populars.length) return SizedBox.shrink();
                return _createPopularItemView(index, _populars.length, _populars[index]);
              },
            ),
          ),
          SizedBox(height: 32),
          Column(
            children: <Widget>[
              Label(
                Settings.locale((s) => s.chat_no_messages_title, ctx: context),
                type: LabelType.h2,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Label(
                Settings.locale((s) => s.chat_no_messages_desc, ctx: context),
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
                  Settings.locale((s) => s.start_chat, ctx: context),
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
                  subscribePopularTopic(model.topic);
                },
                child: Center(
                  child: Text(
                    Settings.locale((s) => s.subscribe, ctx: context),
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

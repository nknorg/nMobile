import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/popular_channel.dart';
import 'package:nmobile/utils/asset.dart';

class ChatNoMessageLayout extends BaseStateFulWidget {
  @override
  _ChatNoMessageLayoutState createState() => _ChatNoMessageLayoutState();
}

class _ChatNoMessageLayoutState extends BaseStateFulWidgetState<ChatNoMessageLayout> {
  List<PopularChannel> _populars = PopularChannel.defaultData();

  @override
  void onRefreshArguments() {}

  Widget _createPopularItemView(int index, int length, PopularChannel model) {
    return Container(
      child: Container(
        width: 120,
        height: 120,
        margin: EdgeInsets.only(left: 20, right: index == length - 1 ? 20 : 12, top: 8, bottom: 8),
        decoration: BoxDecoration(color: application.theme.backgroundColor2, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 20),
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: model.titleBgColor, borderRadius: BorderRadius.circular(8)),
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
            SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 90,
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  decoration: BoxDecoration(color: Color(0xFF5458F7), borderRadius: BorderRadius.circular(100)),
                  child: InkWell(
                    onTap: () {
                      // TODO:GG topic join channel
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(top: 32),
        child: Container(
          child: Flex(
            direction: Axis.vertical,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Label(
                      _localizations.popular_channels,
                      type: LabelType.h3,
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
              Container(
                height: 188,
                margin: const EdgeInsets.only(top: 8),
                child: ListView.builder(
                    itemCount: _populars.length,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      return _createPopularItemView(index, _populars.length, _populars[index]);
                    }),
              ),
              Expanded(
                flex: 0,
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Label(
                        _localizations.chat_no_messages_title,
                        type: LabelType.h2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 8, left: 0, right: 0),
                      child: Label(
                        _localizations.chat_no_messages_desc,
                        type: LabelType.bodyRegular,
                        textAlign: TextAlign.center,
                      ),
                    )
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 54),
                child: Button(
                  height: 54,
                  padding: const EdgeInsets.only(left: 36, right: 36),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Asset.iconSvg('pencil', width: 24, color: application.theme.backgroundLightColor),
                      ),
                      Label(
                        _localizations.start_chat,
                        type: LabelType.h2,
                        dark: true,
                      ),
                    ],
                  ),
                  onPressed: () async {
                    // TODO:GG new private chat
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

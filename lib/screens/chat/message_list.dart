import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/schema/message_item.dart';
import 'package:nmobile/utils/format.dart';

class MessageListScreen extends StatefulWidget {
  @override
  _MessageListScreenState createState() => _MessageListScreenState();
}

class _MessageListScreenState extends State<MessageListScreen> {
  ScrollController _scrollController = ScrollController();

  // todo
  // Widget getTopicItemView(MessageListModel item) {
  //   ContactSchema contact = item.contact;
  //   Widget contentWidget;
  //   LabelType bottomType = LabelType.bodySmall;
  //   String draft = '';
  //   if (NKNClientCaller.currentChatId != null) {
  //     LocalStorage.getChatUnSendContentFromId(
  //         NKNClientCaller.currentChatId, item.targetId);
  //   }
  //   if (draft != null && draft.length > 0) {
  //     contentWidget = Row(
  //       children: <Widget>[
  //         Label(
  //           NL10ns.of(context).placeholder_draft,
  //           type: LabelType.bodySmall,
  //           color: Colors.red,
  //           overflow: TextOverflow.ellipsis,
  //         ),
  //         SizedBox(width: 5),
  //         Label(
  //           draft,
  //           type: bottomType,
  //           overflow: TextOverflow.ellipsis,
  //         ),
  //       ],
  //     );
  //   }
  //   else if (item.contentType == ContentType.nknImage ||
  //       item.contentType == ContentType.media) {
  //     contentWidget = Padding(
  //       padding: const EdgeInsets.only(top: 0),
  //       child: Row(
  //         children: <Widget>[
  //           Label(
  //             contact.getShowName + ': ',
  //             maxLines: 1,
  //             type: LabelType.bodySmall,
  //             overflow: TextOverflow.ellipsis,
  //           ),
  //           loadAssetIconsImage('image',
  //               width: 14, color: DefaultTheme.fontColor2),
  //         ],
  //       ),
  //     );
  //   }
  //   else if (item.contentType == ContentType.nknAudio) {
  //     contentWidget = Padding(
  //       padding: const EdgeInsets.only(top: 0),
  //       child: Row(
  //         children: <Widget>[
  //           Label(
  //             contact.getShowName + ': ',
  //             maxLines: 1,
  //             type: LabelType.bodySmall,
  //             overflow: TextOverflow.ellipsis,
  //           ),
  //           loadAssetIconsImage('microphone',
  //               width: 16.w, color: DefaultTheme.fontColor2),
  //         ],
  //       ),
  //     );
  //   }
  //   else if (item.contentType == ContentType.channelInvitation) {
  //     contentWidget = Label(
  //       contact.getShowName + ': ' + NL10ns.of(context).channel_invitation,
  //       type: bottomType,
  //       maxLines: 1,
  //       overflow: TextOverflow.ellipsis,
  //     );
  //   }
  //   else if (item.contentType == ContentType.eventSubscribe) {
  //     contentWidget = Label(
  //       contact.getShowName + NL10ns.of(context).joined_channel,
  //       maxLines: 1,
  //       type: bottomType,
  //       overflow: TextOverflow.ellipsis,
  //     );
  //   }
  //   else {
  //     contentWidget = Label(
  //       contact.getShowName + ': ' + item.content,
  //       maxLines: 1,
  //       type: bottomType,
  //       overflow: TextOverflow.ellipsis,
  //     );
  //   }
  //   List<Widget> topicWidget = [
  //     _topLabelWidget(item.topic.topicShort),
  //   ];
  //   if (item.topic.isPrivateTopic()) {
  //     topicWidget.insert(
  //         0,
  //         loadAssetIconsImage('lock',
  //             width: 18, color: DefaultTheme.primaryColor));
  //   }
  //   return InkWell(
  //     onTap: () async {
  //       _routeToChatPage(item.topic.topic, true);
  //     },
  //     child: Container(
  //       color: item.isTop ? Colours.light_fb : Colours.transparent,
  //       height: 72,
  //       child: Row(
  //         crossAxisAlignment: CrossAxisAlignment.center,
  //         children: [
  //           Container(
  //             margin: EdgeInsets.only(left: 16, right: 16),
  //             child: CommonUI.avatarWidget(
  //               radiusSize: 24,
  //               topic: item.topic,
  //             ),
  //           ),
  //           Expanded(
  //             child: Container(
  //               decoration: BoxDecoration(
  //                   border: Border(
  //                       bottom: BorderSide(
  //                           width: 0.6,
  //                           color: item.isTop
  //                               ? Colours.light_e5
  //                               : Colours.light_e9))),
  //               child: Row(
  //                 children: [
  //                   Expanded(
  //                     child: Column(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       mainAxisAlignment: MainAxisAlignment.center,
  //                       children: [
  //                         Row(children: topicWidget),
  //                         contentWidget.pad(t: 6),
  //                       ],
  //                     ),
  //                   ),
  //                   Column(
  //                     mainAxisAlignment: MainAxisAlignment.center,
  //                     crossAxisAlignment: CrossAxisAlignment.end,
  //                     children: [
  //                       Label(
  //                         Format.timeFormat(item.lastReceiveTime),
  //                         type: LabelType.bodySmall,
  //                         fontSize: DefaultTheme.chatTimeSize,
  //                       ).pad(r: 20, b: 6),
  //                       _unReadWidget(item),
  //                     ],
  //                   ).pad(l: 12),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _unReadWidget(MessageItem item) {
    String countStr = item.notReadCount.toString();
    if (item.notReadCount > 999) {
      countStr = '999+';
    }
    return Container(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.5),
        child: Container(
          padding: const EdgeInsets.only(left: 10, right: 10),
          color: application.theme.badgeColor,
          height: 25,
          child: Center(
            child: Label(countStr, type: LabelType.bodySmall, dark: true,),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 72),
      controller: _scrollController,
      itemCount: 10,
      itemBuilder: (BuildContext context, int index) {
        if (index % 2 == 0) {
          return Container(
            color: Colors.transparent,
            padding: const EdgeInsets.only(left: 12, right: 12),
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.red,
                    child: Label(
                      'HR',
                      type: LabelType.bodyLarge,
                      color: Colors.yellow,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 0.6, color: application.theme.dividerColor))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Row(children: topicWidget),
                              // contentWidget.pad(t: 6),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 0, bottom: 6),
                              child: Label(
                                timeFormat(DateTime.now()),
                                type: LabelType.bodySmall,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 0),
                              child: _unReadWidget(MessageItem(notReadCount: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          return Container();
        }

        // var item = _messagesList[index];
        // Widget widget;
        // if (item.topic != null) {
        //   widget = getTopicItemView(item);
        // } else {
        //   widget = getSingleChatItemView(item);
        // }
        // return InkWell(
        //   onLongPress: () {
        //     showMenu(item, index);
        //   },
        //   child: widget,
        // );
      },
    );
  }
}

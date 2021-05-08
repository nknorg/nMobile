import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/chat/message_list_item.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/message_list_item.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/utils/format.dart';

class MessageListScreen extends StatefulWidget {
  @override
  _MessageListScreenState createState() => _MessageListScreenState();
}

class _MessageListScreenState extends State<MessageListScreen> {
  ScrollController _scrollController = ScrollController();
  StreamSubscription _statusStreamSubscription;
  StreamSubscription _onMessageStreamSubscription;
  MessageStorage _messageStorage = MessageStorage();
  List<MessageListItem> _messageList = [];

  _sortMessages() {
    setState(() {
      _messageList.sort((a, b) => a.isTop ? (b.isTop ? -1 : -1) : (b.isTop ? 1 : b.lastReceiveTime.compareTo(a.lastReceiveTime)));
    });
  }

  _updateMessage(MessageListItem model) {
    int replaceIndex = -1;
    for (int i = 0; i < _messageList.length; i++) {
      MessageListItem item = _messageList[i];
      if (model.targetId == item.targetId) {
        _messageList.removeAt(i);
        _messageList.insert(i, model);
        replaceIndex = i;
        break;
      }
    }
    if (replaceIndex < 0) {
      _messageList.insert(0, model);
    }
    _sortMessages();
  }

  initAsync() async {
    var messages = await _messageStorage.getLastMessageList(0, 20);
    _messageList = messages;
    _sortMessages();
  }

  @override
  void initState() {
    super.initState();
    initAsync();

    _onMessageStreamSubscription = chat.onMessageSaved.listen((event) {
      _messageStorage.getUpdateMessageList(event.src).then((value) {
        _updateMessage(value);
      });
    });
  }

  @override
  void dispose() {
    _onMessageStreamSubscription?.cancel();
    _statusStreamSubscription?.cancel();
    super.dispose();
  }

  // todo
  // Widget getTopicItemView(MessageListModel item) {  //   ContactSchema contact = item.contact;
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

  // TODO
  _showItemMenu(MessageListItem item, int index) {
    showDialog<Null>(
      context: context,
      builder: (BuildContext context) {
        return new SimpleDialog(
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
          children: [
            SimpleDialogOption(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(item.isTop ? Icons.vertical_align_bottom : Icons.vertical_align_top),
                    ),
                    Text(item.isTop ? S.of(context).top_cancel : S.of(context).top),
                  ],
                ),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                // final top = !item.isTop;
                // final numChanges = await (item.topic == null
                //     ? ContactSchema.setTop(item.targetId, top)
                //     : TopicRepo().updateIsTop(item.topic.topic,
                //     top)); // TopicSchema.setTop(db, item.topic.topic, top));
                // if (numChanges > 0) {
                //   setState(() {
                //     item.isTop = top;
                //     _messageList.remove(item);
                //     _messagesList.insert(0, item);
                //   });
                // }
              },
            ),
            // SimpleDialogOption(
            //   child: Row(
            //     children: [
            //       Icon(Icons.delete_outline).pad(r: 12),
            //       Text(NL10ns.of(context).delete),
            //     ],
            //   ).pad(t: 4, b: 8),
            //   onPressed: () {
            //     Navigator.of(context).pop();
            //     // MessageListModel.deleteTargetChat(item.targetId).then((numChanges) {
            //     //   if (numChanges > 0) {
            //     //     setState(() {
            //     //       _messagesList.remove(item);
            //     //     });
            //     //   }
            //     // });
            //   },
            // ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: 72),
        controller: _scrollController,
        itemCount: _messageList.length,
        itemBuilder: (BuildContext context, int index) {
          var item = _messageList[index];
          Widget widget = createMessageListItemWidget(context, item);

          return InkWell(
            onLongPress: () {
              _showItemMenu(item, index);
            },
            child: widget,
          );
        },
      ),
    );
  }
}

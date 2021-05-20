import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/contact/item.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';

class ContactHomeScreen extends StatefulWidget {
  static const String routeName = '/contact/home';
  static final String argIsSelect = "is_select";

  static Future go(BuildContext context, {bool isSelect = false}) {
    logger.d("contact home - isSelect:$isSelect");
    return Navigator.pushNamed(context, routeName, arguments: {
      argIsSelect: isSelect ?? false,
    });
  }

  final Map<String, dynamic> arguments;

  ContactHomeScreen({Key key, this.arguments}) : super(key: key);

  @override
  _ContactHomeScreenState createState() => _ContactHomeScreenState();
}

class _ContactHomeScreenState extends State<ContactHomeScreen> {
  bool _isSelect = false;

  bool _pageLoaded = false;
  StreamSubscription _addContactSubscription;

  List<ContactSchema> _allFriends = <ContactSchema>[];
  List<ContactSchema> _allStrangers = <ContactSchema>[];
  List<TopicSchema> _allTopics = <TopicSchema>[];

  List<ContactSchema> _searchFriends = <ContactSchema>[];
  List<ContactSchema> _searchStrangers = <ContactSchema>[];
  List<TopicSchema> _searchTopics = <TopicSchema>[];

  @override
  void initState() {
    super.initState();
    this._isSelect = widget.arguments != null ? (widget.arguments[ContactHomeScreen.argIsSelect] ?? false) : false;

    // added
    _addContactSubscription = contact.addStream.listen((ContactSchema scheme) {
      if (scheme == null || scheme.type == null) return;
      if (scheme.type == ContactType.friend) {
        _allFriends.insert(0, scheme);
      } else if (scheme.type == ContactType.friend) {
        _allStrangers.insert(0, scheme);
      }
    });

    // init
    initData();
  }

  @override
  void dispose() {
    super.dispose();
    _addContactSubscription.cancel();
  }

  initData() async {
    var friends = await contact.queryContacts(contactType: ContactType.friend);
    var strangers = await contact.queryContacts(contactType: ContactType.stranger, limit: 20);
    // var topic = widget.arguments ? <TopicSchema>[] : await TopicRepo().getAllTopics();

    setState(() {
      _pageLoaded = true;
      _allFriends = friends ?? [];
      _allStrangers = strangers ?? [];
      // _allTopics = topic ?? [];
    });
  }

  Future _itemOnTap(ContactSchema item) async {
    // if (widget.arguments) {
    //   Navigator.of(context).pop(item);
    // } else {
    //   await Navigator.of(context)
    //       .pushNamed(
    //     ContactScreen.routeName,
    //     arguments: item,
    //   )
    //       .then((v) {
    //     initAsync();
    //   });
    // }
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);

    // int totalCount = (_allTopics.length ?? 0) + (_allFriends.length ?? 0) + (_allStrangers.length ?? 0);

    _searchFriends = _allFriends; // TODO:GG
    _searchTopics = _allTopics; // TODO:GG
    _searchStrangers = _allStrangers; // TODO:GG

    int searchFriendDataCount = _searchFriends.length ?? 0;
    int searchFriendViewCount = (searchFriendDataCount > 0 ? 1 : 0) + searchFriendDataCount;
    int searchTopicDataCount = _searchTopics.length ?? 0;
    int searchTopicViewCount = searchTopicDataCount + (searchTopicDataCount > 0 ? 1 : 0);
    int searchStrangerDataCount = _searchStrangers.length ?? 0;
    int searchStrangerViewCount = (searchStrangerDataCount > 0 ? 1 : 0) + searchStrangerDataCount;

    int listItemViewCount = searchFriendViewCount + searchTopicViewCount + (searchStrangerViewCount > 0 ? 1 : 0) + searchStrangerViewCount;

    // List<Widget> strangerContactList = getStrangeContactList();
    // List<Widget> topicList = getTopicList();
    return Layout(
      headerColor: application.theme.primaryColor,
      header: Header(
        backgroundColor: application.theme.primaryColor,
        // titleChild: GestureDetector(
        //   onTap: () async {
        //     ContactSchema currentUser = await ContactSchema.fetchCurrentUser();
        //     Navigator.of(context).pushNamed(ContactScreen.routeName, arguments: currentUser);
        //   },
        //   child: BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
        //     if (state is AuthToUserState) {
        //       ContactSchema currentUser = state.currentUser;
        //       String currentChatId = NKNClientCaller.currentChatId;
        //       return Flex(
        //         direction: Axis.horizontal,
        //         mainAxisAlignment: MainAxisAlignment.start,
        //         children: <Widget>[
        //           Expanded(
        //             flex: 0,
        //             child: Container(
        //               margin: const EdgeInsets.only(right: 8),
        //               alignment: Alignment.center,
        //               child: Hero(
        //                 tag: 'header_avatar:$currentChatId',
        //                 child: Container(
        //                   child: CommonUI.avatarWidget(
        //                     radiusSize: 24,
        //                     contact: currentUser,
        //                   ),
        //                 ),
        //               ),
        //             ),
        //           ),
        //           Expanded(
        //             flex: 1,
        //             child: Column(
        //               crossAxisAlignment: CrossAxisAlignment.start,
        //               children: <Widget>[
        //                 Label(currentUser.getShowName, type: LabelType.h3, dark: true),
        //                 Label(NL10ns.of(context).connected, type: LabelType.bodySmall, color: DefaultTheme.riseColor),
        //               ],
        //             ),
        //           )
        //         ],
        //       );
        //     }
        //     return Container();
        //   }),
        // ),
        // action: IconButton(
        //   icon: Asset.iconSVG(
        //     'user-plus',
        //     color: DefaultTheme.backgroundLightColor,
        //     width: 24,
        //   ),
        //   onPressed: () {
        //     Navigator.pushNamed(context, AddContact.routeName).then((value) {
        //       if (value != null) {
        //         initAsync();
        //       }
        //     });
        //   },
        // ),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        child: Expanded(
          flex: 1,
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: 60),
            itemCount: listItemViewCount,
            itemBuilder: (context, index) {
              if (searchFriendViewCount > 0 && index >= 0 && index < searchFriendViewCount) {
                if (index == 0) {
                  return Label("好友"); // TODO:GG
                }
                return _getFriendItemView(_searchFriends[index - 1]);
              } else if (searchTopicViewCount > 0 && index >= searchFriendViewCount && index < (searchFriendViewCount + searchTopicViewCount)) {
                if (index == searchFriendViewCount) {
                  return Label("主题"); // TODO:GG
                }
                return SizedBox.shrink(); // TODO:GG
              } else if (searchStrangerViewCount > 0 && index >= (searchFriendViewCount + searchTopicViewCount) && index < (searchFriendViewCount + searchTopicViewCount + searchStrangerViewCount)) {
                if (index == (searchFriendViewCount + searchTopicViewCount)) {
                  return Label("陌生人"); // TODO:GG
                }
                return SizedBox.shrink(); // TODO:GG
              }
              return SizedBox.shrink();
            },
          ),
        ),
        // child: Column(
        //   crossAxisAlignment: CrossAxisAlignment.start,
        //   children: <Widget>[
        //     // Expanded(
        //     //   flex: 0,
        //     //   child: Padding(
        //     //     padding: const EdgeInsets.only(top: 24, bottom: 8),
        //     //     child: Container(
        //     //       decoration: BoxDecoration(
        //     //         color: DefaultTheme.backgroundColor1,
        //     //         borderRadius: BorderRadius.all(Radius.circular(8)),
        //     //       ),
        //     //       child: Flex(
        //     //         direction: Axis.horizontal,
        //     //         crossAxisAlignment: CrossAxisAlignment.end,
        //     //         children: <Widget>[
        //     //           Expanded(
        //     //             flex: 0,
        //     //             child: Container(
        //     //               width: 48,
        //     //               height: 48,
        //     //               alignment: Alignment.center,
        //     //               child: loadAssetIconsImage(
        //     //                 'search',
        //     //                 color: DefaultTheme.fontColor2,
        //     //               ),
        //     //             ),
        //     //           ),
        //     //           Expanded(
        //     //             flex: 1,
        //     //             child: NKNTextField(
        //     //               onChanged: (val) {
        //     //                 searchAction(val);
        //     //               },
        //     //               style: TextStyle(fontSize: 14, height: 1.5),
        //     //               decoration: InputDecoration(
        //     //                 hintText: NL10ns.of(context).search,
        //     //                 contentPadding: const EdgeInsets.only(left: 0, right: 16, top: 9, bottom: 9),
        //     //                 border: UnderlineInputBorder(
        //     //                   borderRadius: BorderRadius.all(Radius.circular(20)),
        //     //                   borderSide: const BorderSide(width: 0, style: BorderStyle.none),
        //     //                 ),
        //     //               ),
        //     //             ),
        //     //           ),
        //     //         ],
        //     //       ),
        //     //     ),
        //     //   ),
        //     // ),
        //     // Expanded(
        //     //   flex: 1,
        //     //   child: ListView(
        //     //     padding: const EdgeInsets.only(bottom: 60),
        //     //     children: <Widget>[
        //     //       Column(
        //     //         crossAxisAlignment: CrossAxisAlignment.start,
        //     //         children: friendList,
        //     //       ),
        //     //       // Column(
        //     //       //   crossAxisAlignment: CrossAxisAlignment.start,
        //     //       //   children: topicList,
        //     //       // ),
        //     //       // Column(
        //     //       //   crossAxisAlignment: CrossAxisAlignment.start,
        //     //       //   children: strangerContactList,
        //     //       // ),
        //     //     ],
        //     //   ),
        //     // ),
        //   ],
        // ),
      ),
    );
  }

  Widget _getFriendItemView(ContactSchema item) {
    S _localizations = S.of(context);

    return Dismissible(
      key: ObjectKey(item),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          return await ModalDialog.of(context).confirm(
            title: _localizations.delete_contact_confirm_title,
            contentWidget: ContactItem(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              contact: item,
              bodyTitle: item?.getDisplayName,
              bodyDesc: item?.clientAddress,
            ),
            agree: Button(
              text: _localizations.delete_contact,
              backgroundColor: application.theme.strongColor,
              width: double.infinity,
              onPressed: () async {
                Navigator.of(context).pop(true);
              },
            ),
            reject: Button(
              text: _localizations.cancel,
              backgroundColor: application.theme.backgroundLightColor,
              fontColor: application.theme.fontColor2,
              width: double.infinity,
              onPressed: () => Navigator.pop(context),
            ),
          );
        }
        return false;
      },
      onDismissed: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // TODO:GG delete
          Toast.show("执行删除");
          // item.deleteContact().then((count) {
          //   if (count > 0) {
          //     setState(() {
          //       _searchFriends.remove(item);
          //     });
          //   }
          // });
        }
      },
      background: Container(
        color: Colors.green,
        child: ListTile(
          leading: Icon(
            Icons.bookmark,
            color: Colors.white,
          ),
        ),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.center,
        child: ListTile(
          trailing: Icon(
            Icons.delete,
            color: Colors.white,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ContactItem(
            contact: item,
            onTap: () {
              // TODO:GG click
              //   _itemOnTap(item);
            },
            bgColor: Colors.transparent,
            bodyTitle: item?.getDisplayName ?? "",
            bodyDesc: timeFormat(item?.updatedTime),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            tail: Padding(
              padding: const EdgeInsets.only(right: 8, left: 16),
              child: Label(
                item.isMe ? 'Me' : '',
                type: LabelType.bodySmall,
              ),
            ),
          ),
          Divider(
            height: 1,
            indent: 74,
            endIndent: 16,
          ),
        ],
      ),
    );
  }

// List<Widget> getStrangeContactList() {
//   List<Widget> strangerContactList = [];
//   if (_searchStrangers.length > 0) {
//     strangerContactList.add(Padding(
//       padding: const EdgeInsets.only(top: 32, bottom: 16),
//       child: Label(
//         '(${_searchStrangers.length}) ${NL10ns.of(context).recent}',
//         type: LabelType.h3,
//         height: 1,
//       ),
//     ));
//   }
//
//   for (var item in _searchStrangers) {
//     strangerContactList.add(InkWell(
//       onTap: () async {
//         _itemOnTap(item);
//       },
//       child: Container(
//         height: 72,
//         padding: const EdgeInsets.only(),
//         child: Flex(
//           direction: Axis.horizontal,
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: <Widget>[
//             Expanded(
//               flex: 0,
//               child: Container(
//                 margin: const EdgeInsets.only(right: 8),
//                 alignment: Alignment.center,
//                 child: Container(
//                   child: CommonUI.avatarWidget(
//                     radiusSize: 24,
//                     contact: item,
//                   ),
//                 ),
//               ),
//             ),
//             Expanded(
//               flex: 1,
//               child: Container(
//                 padding: const EdgeInsets.only(),
//                 decoration: BoxDecoration(
//                   border: Border(bottom: BorderSide(color: DefaultTheme.backgroundColor2)),
//                 ),
//                 child: Flex(
//                   direction: Axis.horizontal,
//                   children: <Widget>[
//                     Expanded(
//                       flex: 1,
//                       child: Container(
//                         alignment: Alignment.centerLeft,
//                         height: 44,
//                         child: Column(
//                           mainAxisSize: MainAxisSize.max,
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: <Widget>[
//                             Label(
//                               item.getShowName,
//                               type: LabelType.h3,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                             Label(
//                               item.clientAddress,
//                               height: 1,
//                               type: LabelType.bodySmall,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     Expanded(
//                       flex: 0,
//                       child: Container(
//                         alignment: Alignment.centerRight,
//                         height: 44,
//                         child: Padding(
//                           padding: const EdgeInsets.only(left: 16),
//                           child: Column(
//                             mainAxisSize: MainAxisSize.max,
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: <Widget>[
//                               Padding(
//                                 padding: const EdgeInsets.only(bottom: 3),
//                                 child: Label(
//                                   item.isMe ? 'Me' : '',
//                                   type: LabelType.bodySmall,
//                                 ),
//                               ),
//                               SizedBox(
//                                 height: 16,
//                               )
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     ));
//   }
//   return strangerContactList;
// }

// List<Widget> getTopicList() {
//   List<Widget> topicList = [];
//   if (_searchTopics.length > 0) {
//     topicList.add(Padding(
//       padding: const EdgeInsets.only(top: 32, bottom: 16),
//       child: Label(
//         '(${_searchTopics.length}) ${NL10ns.of(context).group_chat}',
//         type: LabelType.h3,
//         height: 1,
//       ),
//     ));
//   }
//
//   for (var item in _searchTopics) {
//     topicList.add(InkWell(
//       onTap: () async {
//         Topic topic = await TopicRepo().getTopicByName(item.topic);
//         Navigator.of(context).pushNamed(MessageChatPage.routeName, arguments: topic);
//       },
//       child: Container(
//         height: 72,
//         padding: const EdgeInsets.only(),
//         child: Flex(
//           direction: Axis.horizontal,
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: <Widget>[
//             Expanded(
//               flex: 0,
//               child: Container(
//                 margin: const EdgeInsets.only(right: 8),
//                 alignment: Alignment.center,
//                 child: Container(
//                   child: CommonUI.avatarWidget(
//                     radiusSize: 24,
//                     topic: item,
//                   ),
//                 ),
//               ),
//             ),
//             Expanded(
//               flex: 1,
//               child: Container(
//                 padding: const EdgeInsets.only(),
//                 decoration: BoxDecoration(
//                   border: Border(bottom: BorderSide(color: DefaultTheme.backgroundColor2)),
//                 ),
//                 child: Flex(
//                   direction: Axis.horizontal,
//                   children: <Widget>[
//                     Expanded(
//                       flex: 1,
//                       child: Container(
//                         alignment: Alignment.centerLeft,
//                         height: 44,
//                         child: Column(
//                           mainAxisSize: MainAxisSize.max,
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: <Widget>[
//                             Row(
//                               children: <Widget>[
//                                 item.isPrivateTopic()
//                                     ? loadAssetIconsImage(
//                                         'lock',
//                                         width: 18,
//                                         color: DefaultTheme.primaryColor,
//                                       )
//                                     : Container(),
//                                 Label(
//                                   item.topicShort,
//                                   type: LabelType.h3,
//                                   overflow: TextOverflow.ellipsis,
//                                 ),
//                               ],
//                             ),
//                             Label(
//                               item.topic,
//                               height: 1,
//                               type: LabelType.bodySmall,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     ));
//   }
//   return topicList;
// }

// searchAction(String val) {
//   if (val.length == 0) {
//     setState(() {
//       _searchFriends = _allFriends;
//       _searchStrangers = _allStrangers;
//       _searchTopics = _allTopics;
//     });
//   } else {
//     setState(() {
//       _searchStrangers = _allStrangers.where((ContactSchema e) => e.getShowName.toLowerCase().contains(val.toLowerCase())).toList();
//       _searchFriends = _allFriends.where((ContactSchema e) => e.getShowName.contains(val)).toList();
//       _searchTopics = _allTopics.where((Topic e) => e.topic.contains(val)).toList();
//     });
//   }
// }
}

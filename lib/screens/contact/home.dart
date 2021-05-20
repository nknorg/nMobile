import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/schema/contact.dart';

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

  // ScrollController _scrollController = ScrollController();
  // List<ContactSchema> _friends = <ContactSchema>[];
  // List<ContactSchema> _strangerContacts = <ContactSchema>[];
  // List<TopicSchema> _topic = <TopicSchema>[];
  //
  // List<ContactSchema> _allFriends = <ContactSchema>[];
  // List<ContactSchema> _allStrangerContacts = <ContactSchema>[];
  // List<TopicSchema> _allTopic = <TopicSchema>[];
  // int _limit = 100;
  // int _skip = 20;
  // bool loading = false;
  // String searchText = '';
  // ContactBloc _contactBloc;
  // StreamSubscription _addContactSubscription;

  @override
  void initState() {
    super.initState();
    this._isSelect = widget.arguments != null ? (widget.arguments[ContactHomeScreen.argIsSelect] ?? false) : false;

    // _contactBloc = BlocProvider.of<ContactBloc>(context);
    //
    // _addContactSubscription = eventBus.on<AddContactEvent>().listen((event) {
    //   initAsync();
    // });
    // initAsync();
  }

  @override
  void dispose() {
    super.dispose();
    // _addContactSubscription.cancel();
  }

  initAsync() async {
    // var topic = widget.arguments ? <TopicSchema>[] : await TopicRepo().getAllTopics();
    //
    // var friends = await ContactSchema.getContacts(limit: _limit);
    // var stranger = await ContactSchema.getStrangerContacts(limit: 10);
    // setState(() {
    //   _friends = friends ?? [];
    //   _strangerContacts = stranger ?? [];
    //   _topic = topic ?? [];
    //
    //   _allFriends = _friends;
    //   _allStrangerContacts = _strangerContacts;
    //   _allTopic = _topic;
    // });
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
    return Container();
    // if (_allTopic.length > 0 || _allStrangerContacts.length > 0 || searchText.length != 0 || _allFriends.length > 0) {
    //   List<Widget> friendList = getFriendItemView();
    //   List<Widget> strangerContactList = getStrangeContactList();
    //   List<Widget> topicList = getTopicList();
    //   return Scaffold(
    //     backgroundColor: DefaultTheme.primaryColor,
    //     appBar: Header(
    //       titleChild: GestureDetector(
    //         onTap: () async {
    //           ContactSchema currentUser = await ContactSchema.fetchCurrentUser();
    //           Navigator.of(context).pushNamed(ContactScreen.routeName, arguments: currentUser);
    //         },
    //         child: BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
    //           if (state is AuthToUserState) {
    //             ContactSchema currentUser = state.currentUser;
    //             String currentChatId = NKNClientCaller.currentChatId;
    //             return Flex(
    //               direction: Axis.horizontal,
    //               mainAxisAlignment: MainAxisAlignment.start,
    //               children: <Widget>[
    //                 Expanded(
    //                   flex: 0,
    //                   child: Container(
    //                     margin: const EdgeInsets.only(right: 8),
    //                     alignment: Alignment.center,
    //                     child: Hero(
    //                       tag: 'header_avatar:$currentChatId',
    //                       child: Container(
    //                         child: CommonUI.avatarWidget(
    //                           radiusSize: 24,
    //                           contact: currentUser,
    //                         ),
    //                       ),
    //                     ),
    //                   ),
    //                 ),
    //                 Expanded(
    //                   flex: 1,
    //                   child: Column(
    //                     crossAxisAlignment: CrossAxisAlignment.start,
    //                     children: <Widget>[
    //                       Label(currentUser.getShowName, type: LabelType.h3, dark: true),
    //                       Label(NL10ns.of(context).connected, type: LabelType.bodySmall, color: DefaultTheme.riseColor),
    //                     ],
    //                   ),
    //                 )
    //               ],
    //             );
    //           }
    //           return Container();
    //         }),
    //       ),
    //       backgroundColor: DefaultTheme.primaryColor,
    //       action: IconButton(
    //         icon: Asset.iconSVG(
    //           'user-plus',
    //           color: DefaultTheme.backgroundLightColor,
    //           width: 24,
    //         ),
    //         onPressed: () {
    //           Navigator.pushNamed(context, AddContact.routeName).then((value) {
    //             if (value != null) {
    //               initAsync();
    //             }
    //           });
    //         },
    //       ),
    //     ),
    //     body: GestureDetector(
    //       onTap: () {
    //         FocusScope.of(context).requestFocus(FocusNode());
    //       },
    //       child: BodyBox(
    //         padding: const EdgeInsets.only(top: 0, left: 20, right: 20),
    //         color: DefaultTheme.backgroundLightColor,
    //         child: Flex(
    //           crossAxisAlignment: CrossAxisAlignment.start,
    //           direction: Axis.vertical,
    //           children: <Widget>[
    //             Expanded(
    //               flex: 0,
    //               child: Padding(
    //                 padding: const EdgeInsets.only(top: 24, bottom: 8),
    //                 child: Container(
    //                   decoration: BoxDecoration(
    //                     color: DefaultTheme.backgroundColor1,
    //                     borderRadius: BorderRadius.all(Radius.circular(8)),
    //                   ),
    //                   child: Flex(
    //                     direction: Axis.horizontal,
    //                     crossAxisAlignment: CrossAxisAlignment.end,
    //                     children: <Widget>[
    //                       Expanded(
    //                         flex: 0,
    //                         child: Container(
    //                           width: 48,
    //                           height: 48,
    //                           alignment: Alignment.center,
    //                           child: loadAssetIconsImage(
    //                             'search',
    //                             color: DefaultTheme.fontColor2,
    //                           ),
    //                         ),
    //                       ),
    //                       Expanded(
    //                         flex: 1,
    //                         child: NKNTextField(
    //                           onChanged: (val) {
    //                             searchAction(val);
    //                           },
    //                           style: TextStyle(fontSize: 14, height: 1.5),
    //                           decoration: InputDecoration(
    //                             hintText: NL10ns.of(context).search,
    //                             contentPadding: const EdgeInsets.only(left: 0, right: 16, top: 9, bottom: 9),
    //                             border: UnderlineInputBorder(
    //                               borderRadius: BorderRadius.all(Radius.circular(20)),
    //                               borderSide: const BorderSide(width: 0, style: BorderStyle.none),
    //                             ),
    //                           ),
    //                         ),
    //                       ),
    //                     ],
    //                   ),
    //                 ),
    //               ),
    //             ),
    //             Expanded(
    //               flex: 1,
    //               child: ListView(
    //                 padding: const EdgeInsets.only(bottom: 60),
    //                 controller: _scrollController,
    //                 children: <Widget>[
    //                   Column(
    //                     crossAxisAlignment: CrossAxisAlignment.start,
    //                     children: friendList,
    //                   ),
    //                   Column(
    //                     crossAxisAlignment: CrossAxisAlignment.start,
    //                     children: topicList,
    //                   ),
    //                   Column(
    //                     crossAxisAlignment: CrossAxisAlignment.start,
    //                     children: strangerContactList,
    //                   ),
    //                 ],
    //               ),
    //             ),
    //           ],
    //         ),
    //       ),
    //     ),
    //   );
    // } else {
    //   return NoContactScreen();
    // }
  }

  // List<Widget> getFriendItemView() {
  //   List<Widget> contactList = [];
  //   if (_friends.length > 0) {
  //     contactList.add(Padding(
  //       padding: const EdgeInsets.only(top: 16, bottom: 16),
  //       child: Label(
  //         '(${_friends.length}) ${NL10ns.of(context).friends}',
  //         type: LabelType.h3,
  //         height: 1,
  //       ),
  //     ));
  //   }
  //
  //   for (var item in _friends) {
  //     contactList.add(Dismissible(
  //       key: ObjectKey(item),
  //       direction: DismissDirection.endToStart,
  //       confirmDismiss: (direction) async {
  //         if (direction == DismissDirection.endToStart) {
  //           var isDismiss = await ModalDialog.of(context).confirm(
  //             height: 380,
  //             title: Label(
  //               NL10ns.of(context).delete_contact_confirm_title,
  //               type: LabelType.h2,
  //               softWrap: true,
  //             ),
  //             content: Column(
  //               children: <Widget>[
  //                 Container(
  //                   child: Container(
  //                     height: 80,
  //                     padding: const EdgeInsets.only(),
  //                     child: Flex(
  //                       direction: Axis.horizontal,
  //                       crossAxisAlignment: CrossAxisAlignment.stretch,
  //                       children: <Widget>[
  //                         Expanded(
  //                           flex: 0,
  //                           child: Container(
  //                             margin: const EdgeInsets.only(right: 8),
  //                             alignment: Alignment.center,
  //                             child: Hero(
  //                               tag: 'avatar:${item.clientAddress}',
  //                               child: Container(
  //                                 child: CommonUI.avatarWidget(
  //                                   radiusSize: 24,
  //                                   contact: item,
  //                                 ),
  //                               ),
  //                             ),
  //                           ),
  //                         ),
  //                         Expanded(
  //                           flex: 1,
  //                           child: Flex(
  //                             direction: Axis.horizontal,
  //                             children: <Widget>[
  //                               Expanded(
  //                                 flex: 1,
  //                                 child: Container(
  //                                   alignment: Alignment.centerLeft,
  //                                   height: 50,
  //                                   child: Column(
  //                                     mainAxisSize: MainAxisSize.max,
  //                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                                     crossAxisAlignment: CrossAxisAlignment.start,
  //                                     children: <Widget>[
  //                                       Label(
  //                                         item.getShowName,
  //                                         type: LabelType.h3,
  //                                       ),
  //                                       Row(
  //                                         children: <Widget>[
  //                                           Expanded(
  //                                             child: Label(
  //                                               item.clientAddress,
  //                                               softWrap: true,
  //                                               type: LabelType.bodyRegular,
  //                                               overflow: TextOverflow.ellipsis,
  //                                             ),
  //                                           ),
  //                                         ],
  //                                       ),
  //                                     ],
  //                                   ),
  //                                 ),
  //                               ),
  //                             ],
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             agree: Padding(
  //               padding: const EdgeInsets.only(bottom: 8),
  //               child: Button(
  //                 child: Row(
  //                   mainAxisAlignment: MainAxisAlignment.center,
  //                   children: <Widget>[
  //                     Padding(
  //                       padding: const EdgeInsets.only(right: 8),
  //                       child: loadAssetIconsImage(
  //                         'trash',
  //                         color: DefaultTheme.backgroundLightColor,
  //                         width: 24,
  //                       ),
  //                     ),
  //                     Label(
  //                       NL10ns.of(context).delete,
  //                       type: LabelType.h3,
  //                     )
  //                   ],
  //                 ),
  //                 backgroundColor: DefaultTheme.strongColor,
  //                 width: double.infinity,
  //                 onPressed: () {
  //                   Navigator.of(context).pop(true);
  //                 },
  //               ),
  //             ),
  //             reject: Button(
  //               backgroundColor: DefaultTheme.backgroundLightColor,
  //               fontColor: DefaultTheme.fontColor2,
  //               text: NL10ns.of(context).cancel,
  //               width: double.infinity,
  //               onPressed: () => Navigator.of(context).pop(),
  //             ),
  //           );
  //           return isDismiss;
  //         }
  //         return false;
  //       },
  //       onDismissed: (direction) async {
  //         if (direction == DismissDirection.endToStart) {
  //           item.deleteContact().then((count) {
  //             if (count > 0) {
  //               setState(() {
  //                 _friends.remove(item);
  //               });
  //             }
  //           });
  //         }
  //       },
  //       background: Container(
  //         color: Colors.green,
  //         child: ListTile(
  //           leading: Icon(
  //             Icons.bookmark,
  //             color: Colors.white,
  //           ),
  //         ),
  //       ),
  //       secondaryBackground: Container(
  //         color: Colors.red,
  //         alignment: Alignment.center,
  //         child: ListTile(
  //           trailing: Icon(
  //             Icons.delete,
  //             color: Colors.white,
  //           ),
  //         ),
  //       ),
  //       child: InkWell(
  //         onTap: () async {
  //           _itemOnTap(item);
  //         },
  //         child: Container(
  //           height: 72,
  //           padding: const EdgeInsets.only(),
  //           child: Flex(
  //             direction: Axis.horizontal,
  //             crossAxisAlignment: CrossAxisAlignment.stretch,
  //             children: <Widget>[
  //               Expanded(
  //                 flex: 0,
  //                 child: Container(
  //                   margin: const EdgeInsets.only(right: 8),
  //                   alignment: Alignment.center,
  //                   child: Container(
  //                     child: CommonUI.avatarWidget(radiusSize: 24, contact: item),
  //                   ),
  //                 ),
  //               ),
  //               Expanded(
  //                 flex: 1,
  //                 child: Container(
  //                   padding: const EdgeInsets.only(),
  //                   decoration: BoxDecoration(
  //                     border: Border(bottom: BorderSide(color: DefaultTheme.backgroundColor2)),
  //                   ),
  //                   child: Flex(
  //                     direction: Axis.horizontal,
  //                     children: <Widget>[
  //                       Expanded(
  //                         flex: 1,
  //                         child: Container(
  //                           alignment: Alignment.centerLeft,
  //                           height: 44,
  //                           child: Column(
  //                             mainAxisSize: MainAxisSize.max,
  //                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                             crossAxisAlignment: CrossAxisAlignment.start,
  //                             children: <Widget>[
  //                               Label(
  //                                 item.getShowName,
  //                                 type: LabelType.h3,
  //                                 overflow: TextOverflow.ellipsis,
  //                               ),
  //                               Label(
  //                                 Format.timeFormat(item.updatedTime),
  //                                 height: 1,
  //                                 type: LabelType.bodySmall,
  //                                 overflow: TextOverflow.ellipsis,
  //                               ),
  //                             ],
  //                           ),
  //                         ),
  //                       ),
  //                       Expanded(
  //                         flex: 0,
  //                         child: Container(
  //                           alignment: Alignment.centerRight,
  //                           height: 44,
  //                           child: Padding(
  //                             padding: const EdgeInsets.only(left: 16),
  //                             child: Column(
  //                               mainAxisSize: MainAxisSize.max,
  //                               mainAxisAlignment: MainAxisAlignment.center,
  //                               children: <Widget>[
  //                                 Padding(
  //                                   padding: const EdgeInsets.only(bottom: 3),
  //                                   child: Label(
  //                                     item.isMe ? 'Me' : '',
  //                                     type: LabelType.bodySmall,
  //                                   ),
  //                                 ),
  //                                 SizedBox(
  //                                   height: 16,
  //                                 )
  //                               ],
  //                             ),
  //                           ),
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ));
  //   }
  //
  //   return contactList;
  // }

  // List<Widget> getStrangeContactList() {
  //   List<Widget> strangerContactList = [];
  //   if (_strangerContacts.length > 0) {
  //     strangerContactList.add(Padding(
  //       padding: const EdgeInsets.only(top: 32, bottom: 16),
  //       child: Label(
  //         '(${_strangerContacts.length}) ${NL10ns.of(context).recent}',
  //         type: LabelType.h3,
  //         height: 1,
  //       ),
  //     ));
  //   }
  //
  //   for (var item in _strangerContacts) {
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
  //   if (_topic.length > 0) {
  //     topicList.add(Padding(
  //       padding: const EdgeInsets.only(top: 32, bottom: 16),
  //       child: Label(
  //         '(${_topic.length}) ${NL10ns.of(context).group_chat}',
  //         type: LabelType.h3,
  //         height: 1,
  //       ),
  //     ));
  //   }
  //
  //   for (var item in _topic) {
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
  //       _friends = _allFriends;
  //       _strangerContacts = _allStrangerContacts;
  //       _topic = _allTopic;
  //     });
  //   } else {
  //     setState(() {
  //       _strangerContacts = _allStrangerContacts.where((ContactSchema e) => e.getShowName.toLowerCase().contains(val.toLowerCase())).toList();
  //       _friends = _allFriends.where((ContactSchema e) => e.getShowName.contains(val)).toList();
  //       _topic = _allTopic.where((Topic e) => e.topic.contains(val)).toList();
  //     });
  //   }
  // }
}

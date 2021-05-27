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
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/contact/add.dart';
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';

import 'home_empty.dart';

class ContactHomeScreen extends StatefulWidget {
  static const String routeName = '/contact/home';
  static final String argIsSelect = "is_select";

  static Future go(BuildContext context, {bool isSelect = false}) {
    logger.d("contact home - isSelect:$isSelect");
    return Navigator.pushNamed(context, routeName, arguments: {
      argIsSelect: isSelect,
    });
  }

  final Map<String, dynamic>? arguments;

  ContactHomeScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _ContactHomeScreenState createState() => _ContactHomeScreenState();
}

class _ContactHomeScreenState extends State<ContactHomeScreen> {
  bool _isSelect = false;

  bool _pageLoaded = false;
  late StreamSubscription _addContactSubscription;
  late StreamSubscription _deleteContactSubscription;
  late StreamSubscription _updateContactSubscription;

  TextEditingController _searchController = TextEditingController();

  List<ContactSchema> _allFriends = <ContactSchema>[];
  List<ContactSchema> _allStrangers = <ContactSchema>[];
  List<TopicSchema> _allTopics = <TopicSchema>[];

  List<ContactSchema> _searchFriends = <ContactSchema>[];
  List<ContactSchema> _searchStrangers = <ContactSchema>[];
  List<TopicSchema> _searchTopics = <TopicSchema>[];

  @override
  void initState() {
    super.initState();
    this._isSelect = widget.arguments![ContactHomeScreen.argIsSelect] ?? false;

    // listen
    _addContactSubscription = contactCommon.addStream.listen((ContactSchema scheme) {
      if (scheme.type == ContactType.friend) {
        _allFriends.insert(0, scheme);
      } else if (scheme.type == ContactType.friend) {
        _allStrangers.insert(0, scheme);
      }
      _searchAction(_searchController.text);
    });
    _deleteContactSubscription = contactCommon.deleteStream.listen((int contactId) {
      _allFriends = _allFriends.where((element) => element.id != contactId).toList();
      _searchAction(_searchController.text);
    });
    _updateContactSubscription = contactCommon.updateStream.listen((List<ContactSchema> list) {
      if (list.isEmpty) return;
      if (list.length == 1) {
        int friendIndex = -1;
        _allFriends.asMap().forEach((key, value) {
          if (value.id == list[0].id) {
            friendIndex = key;
          }
        });
        if (friendIndex >= 0 && friendIndex < (_allFriends.length)) {
          _allFriends[friendIndex] = list[0];
          _searchAction(_searchController.text);
          return;
        }
        int strangerIndex = -1;
        _allStrangers.asMap().forEach((key, value) {
          if (value.id == list[0].id) {
            strangerIndex = key;
          }
        });
        if (friendIndex >= 0 && strangerIndex < (_allStrangers.length)) {
          _allStrangers[strangerIndex] = list[0];
          _searchAction(_searchController.text);
          return;
        }
      } else {
        _initData();
      }
    });

    // init
    _initData();
  }

  @override
  void dispose() {
    super.dispose();
    _addContactSubscription.cancel();
    _deleteContactSubscription.cancel();
    _updateContactSubscription.cancel();
  }

  _initData() async {
    List<ContactSchema> friends = await contactCommon.queryContacts(contactType: ContactType.friend);
    List<ContactSchema> strangers = await contactCommon.queryContacts(contactType: ContactType.stranger, limit: 20);
    List<TopicSchema> topics = []; // widget.arguments ? <TopicSchema>[] : await TopicRepo().getAllTopics(); // TODO:GG topic
    topics = (this._isSelect == true) ? [] : topics; // TODO:GG can not write this line in state

    setState(() {
      _pageLoaded = true;
      // total
      _allFriends = friends;
      _allStrangers = strangers;
      _allTopics = topics;
      // search
      _searchFriends = _allFriends;
      _searchStrangers = _allStrangers;
      _searchTopics = _allTopics;
    });

    _searchAction(_searchController.text);
  }

  _searchAction(String? val) {
    if (val == null || val.isEmpty) {
      setState(() {
        _searchFriends = _allFriends;
        _searchStrangers = _allStrangers;
        _searchTopics = _allTopics;
      });
    } else {
      setState(() {
        _searchStrangers = _allStrangers.where((ContactSchema e) => e.getDisplayName.toLowerCase().contains(val.toLowerCase())).toList();
        _searchFriends = _allFriends.where((ContactSchema e) => e.getDisplayName.toLowerCase().contains(val.toLowerCase())).toList();
        // _searchTopics = _allTopics.where((Topic e) => e.topic.contains(val)).toList(); // TODO:GG topic
      });
    }
  }

  _onTapContactItem(ContactSchema item) async {
    if (this._isSelect) {
      Navigator.pop(context, item);
    } else {
      ContactProfileScreen.go(context, schema: item);
    }
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);

    int totalFriendDataCount = _allFriends.length;
    int totalTopicDataCount = _allTopics.length;
    int totalStrangerDataCount = _allStrangers.length;

    int totalDataCount = totalFriendDataCount + totalTopicDataCount + totalStrangerDataCount;
    if (totalDataCount <= 0 && _pageLoaded) {
      return ContactHomeEmptyLayout();
    }

    int searchFriendDataCount = _searchFriends.length;
    int searchFriendViewCount = (searchFriendDataCount > 0 ? 1 : 0) + searchFriendDataCount;
    int searchTopicDataCount = _searchTopics.length;
    int searchTopicViewCount = searchTopicDataCount + (searchTopicDataCount > 0 ? 1 : 0);
    int searchStrangerDataCount = _searchStrangers.length;
    int searchStrangerViewCount = (searchStrangerDataCount > 0 ? 1 : 0) + searchStrangerDataCount;

    int listItemViewCount = searchFriendViewCount + searchTopicViewCount + (searchStrangerViewCount > 0 ? 1 : 0) + searchStrangerViewCount;

    return Layout(
      headerColor: application.theme.primaryColor,
      header: Header(
        title: _localizations.contacts,
        actions: [
          IconButton(
            icon: Asset.iconSvg(
              'user-plus',
              color: application.theme.backgroundLightColor,
              width: 24,
            ),
            onPressed: () {
              ContactAddScreen.go(context);
            },
          )
        ],
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: application.theme.backgroundColor2,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: 0,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: Asset.iconSvg(
                          'search',
                          color: application.theme.fontColor2,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          _searchAction(val);
                        },
                        style: TextStyle(fontSize: 14, height: 1.5),
                        decoration: InputDecoration(
                          hintText: _localizations.search,
                          contentPadding: const EdgeInsets.only(left: 0, right: 16, top: 9, bottom: 9),
                          border: UnderlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            borderSide: const BorderSide(width: 0, style: BorderStyle.none),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: ListView.builder(
                padding: EdgeInsets.only(bottom: 60),
                itemCount: listItemViewCount,
                itemBuilder: (context, index) {
                  if (searchFriendViewCount > 0 && index >= 0 && index < searchFriendViewCount) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 16, left: 16, right: 16),
                        child: Label(
                          '($searchFriendDataCount) ${_localizations.friends}',
                          type: LabelType.h3,
                        ),
                      );
                    }
                    return _getFriendItemView(_searchFriends[index - 1]);
                  } else if (searchTopicViewCount > 0 && index >= searchFriendViewCount && index < (searchFriendViewCount + searchTopicViewCount)) {
                    if (index == searchFriendViewCount) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 16, left: 16, right: 16),
                        child: Label(
                          '($searchTopicDataCount) ${_localizations.group_chat}',
                          type: LabelType.h3,
                        ),
                      );
                    }
                    return _getStrangerItemView(_searchStrangers[index - (searchFriendViewCount > 0 ? 2 : 1)]);
                  } else if (searchStrangerViewCount > 0 && index >= (searchFriendViewCount + searchTopicViewCount) && index < (searchFriendViewCount + searchTopicViewCount + searchStrangerViewCount)) {
                    if (index == (searchFriendViewCount + searchTopicViewCount)) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 16, left: 16, right: 16),
                        child: Label(
                          '($searchStrangerDataCount) ${_localizations.recent}',
                          type: LabelType.h3,
                        ),
                      );
                    }
                    return SizedBox.shrink(); // TODO:GG topic
                  }
                  return SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
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
              bodyTitle: item.getDisplayName,
              bodyDesc: item.clientAddress,
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
          await contactCommon.delete(item.id);
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
              _onTapContactItem(item);
            },
            bgColor: Colors.transparent,
            bodyTitle: item.getDisplayName,
            bodyDesc: timeFormat(item.updatedTime),
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

  Widget _getStrangerItemView(ContactSchema item) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ContactItem(
          contact: item,
          onTap: () {
            _onTapContactItem(item);
          },
          bgColor: Colors.transparent,
          bodyTitle: item.clientAddress,
          bodyDesc: timeFormat(item.updatedTime),
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
    );
  }

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

}

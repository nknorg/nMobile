import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/contact/item.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/fixed_text_field.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/components/topic/item.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/screens/contact/add.dart';
import 'package:nmobile/screens/contact/home_empty.dart';
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/format.dart';
import 'package:nmobile/utils/logger.dart';

class ContactHomeScreen extends BaseStateFulWidget {
  static const String routeName = '/contact/home';
  static final String argIsSelect = "is_select";

  static Future go(BuildContext context, {bool isSelect = false}) {
    logger.d("ContactHomeScreen - go - isSelect:$isSelect");
    return Navigator.pushNamed(context, routeName, arguments: {
      argIsSelect: isSelect,
    });
  }

  final Map<String, dynamic>? arguments;

  ContactHomeScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _ContactHomeScreenState createState() => _ContactHomeScreenState();
}

class _ContactHomeScreenState extends BaseStateFulWidgetState<ContactHomeScreen> {
  bool _isSelect = false;

  bool _pageLoaded = false;
  StreamSubscription? _addContactSubscription;
  // StreamSubscription? _deleteContactSubscription;
  StreamSubscription? _updateContactSubscription;

  StreamSubscription? _addTopicSubscription;
  // StreamSubscription? _deleteTopicSubscription;
  StreamSubscription? _updateTopicSubscription;

  TextEditingController _searchController = TextEditingController();

  List<ContactSchema> _allFriends = <ContactSchema>[];
  List<ContactSchema> _allStrangers = <ContactSchema>[];
  List<TopicSchema> _allTopics = <TopicSchema>[];

  List<ContactSchema> _searchFriends = <ContactSchema>[];
  List<ContactSchema> _searchStrangers = <ContactSchema>[];
  List<TopicSchema> _searchTopics = <TopicSchema>[];

  @override
  void onRefreshArguments() {
    this._isSelect = widget.arguments![ContactHomeScreen.argIsSelect] ?? false;
  }

  @override
  void initState() {
    super.initState();
    // contact listen
    _addContactSubscription = contactCommon.addStream.listen((ContactSchema schema) {
      if (schema.type == ContactType.friend) {
        _allFriends.insert(0, schema);
      } else if (schema.type == ContactType.friend) {
        _allStrangers.insert(0, schema);
      }
      _searchAction(_searchController.text);
    });
    // _deleteContactSubscription = contactCommon.deleteStream.listen((int contactId) {
    //   _allFriends = _allFriends.where((element) => element.id != contactId).toList();
    //   _allStrangers = _allStrangers.where((element) => element.id != contactId).toList();
    //   _searchAction(_searchController.text);
    // });
    _updateContactSubscription = contactCommon.updateStream.listen((ContactSchema event) {
      // friend
      int friendIndex = -1;
      _allFriends.asMap().forEach((key, value) {
        if (value.id == event.id) {
          friendIndex = key;
        }
      });
      if (friendIndex >= 0 && friendIndex < (_allFriends.length)) {
        if (event.type == ContactType.friend) {
          _allFriends[friendIndex] = event;
        } else {
          _allFriends.removeAt(friendIndex);
        }
        _searchAction(_searchController.text);
      }
      // stranger
      int strangerIndex = -1;
      _allStrangers.asMap().forEach((key, value) {
        if (value.id == event.id) {
          strangerIndex = key;
        }
      });
      if (strangerIndex >= 0 && strangerIndex < (_allStrangers.length)) {
        if (event.type == ContactType.stranger) {
          _allStrangers[strangerIndex] = event;
        } else {
          _allStrangers.removeAt(strangerIndex);
        }
        _searchAction(_searchController.text);
      }
      // type
      if ((friendIndex < 0) && (event.type == ContactType.friend)) {
        _allFriends.insert(0, event);
        _searchAction(_searchController.text);
      } else if ((strangerIndex < 0) && (event.type == ContactType.stranger)) {
        _allStrangers.insert(0, event);
        _searchAction(_searchController.text);
      }
    });

    // topic listen
    _addTopicSubscription = topicCommon.addStream.listen((TopicSchema schema) {
      _allTopics.insert(0, schema);
      _searchAction(_searchController.text);
    });
    // _deleteTopicSubscription = topicCommon.deleteStream.listen((String topic) {
    //   _allTopics = _allTopics.where((element) => element.topic != topic).toList();
    //   _searchAction(_searchController.text);
    // });
    _updateContactSubscription = topicCommon.updateStream.listen((TopicSchema event) {
      _allTopics = _allTopics.map((e) => e.id == event.id ? event : e).toList();
      if (!event.joined) {
        _allTopics = _allTopics.where((element) => element.topic != event.topic).toList();
      }
      _searchAction(_searchController.text);
    });

    // init
    _initData();
  }

  @override
  void dispose() {
    _addContactSubscription?.cancel();
    // _deleteContactSubscription?.cancel();
    _updateContactSubscription?.cancel();
    _addTopicSubscription?.cancel();
    // _deleteTopicSubscription?.cancel();
    _updateTopicSubscription?.cancel();
    super.dispose();
  }

  _initData() async {
    int limit = 20;
    List<ContactSchema> friends = [];
    for (int offset = 0; true; offset += limit) {
      List<ContactSchema> result = await contactCommon.queryList(contactType: ContactType.friend, offset: offset, limit: limit);
      friends.addAll(result);
      if (result.length < limit) break;
    }
    List<ContactSchema> strangers = await contactCommon.queryList(contactType: ContactType.stranger, limit: 20);
    List<TopicSchema> topics = [];
    for (int offset = 0; true; offset += limit) {
      List<TopicSchema> result = await topicCommon.queryListJoined(offset: offset, limit: limit);
      topics.addAll(result);
      if (result.length < limit) break;
    }
    topics = (this._isSelect == true) ? [] : topics; // can not move this line to setState

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
        _searchStrangers = _allStrangers.where((ContactSchema e) => e.displayName.toLowerCase().contains(val.toLowerCase())).toList();
        _searchFriends = _allFriends.where((ContactSchema e) => e.displayName.toLowerCase().contains(val.toLowerCase())).toList();
        _searchTopics = _allTopics.where((TopicSchema e) => e.topic.contains(val)).toList();
      });
    }
  }

  _onTapContactItem(ContactSchema item) async {
    if (this._isSelect) {
      if (Navigator.of(this.context).canPop()) Navigator.pop(this.context, item);
    } else {
      ContactProfileScreen.go(context, schema: item);
    }
  }

  _onTapTopicItem(TopicSchema item) async {
    //TopicProfileScreen.go(context, schema: item);
    ChatMessagesScreen.go(context, item);
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(Global.appContext);

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
    int searchTopicViewCount = (searchTopicDataCount > 0 ? 1 : 0) + searchTopicDataCount;
    int searchStrangerDataCount = _searchStrangers.length;
    int searchStrangerViewCount = (searchStrangerDataCount > 0 ? 1 : 0) + searchStrangerDataCount;

    int listItemViewCount = searchFriendViewCount + searchTopicViewCount + searchStrangerViewCount;

    int friendStartIndex = 0;
    int friendEndIndex = searchFriendViewCount - 1;
    int topicStartIndex = friendEndIndex + 1;
    int topicEndIndex = topicStartIndex + searchTopicViewCount - 1;
    int strangerStartIndex = topicEndIndex + 1;
    int strangerEndIndex = strangerStartIndex + searchStrangerViewCount - 1;

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
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: Asset.iconSvg(
                        'search',
                        color: application.theme.fontColor2,
                      ),
                    ),
                    Expanded(
                      child: FixedTextField(
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
              child: ListView.builder(
                padding: EdgeInsets.only(bottom: 72),
                itemCount: listItemViewCount,
                itemBuilder: (context, index) {
                  int friendItemIndex = index - 1;
                  int topicItemIndex = index - searchFriendViewCount - 1;
                  int strangerItemIndex = index - searchTopicViewCount - searchFriendViewCount - 1;

                  if (searchFriendViewCount > 0 && index >= friendStartIndex && index <= friendEndIndex) {
                    if (index == friendStartIndex) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 16, left: 16, right: 16),
                        child: Label(
                          '($searchFriendDataCount) ${_localizations.friends}',
                          type: LabelType.h3,
                        ),
                      );
                    }
                    return _getFriendItemView(_searchFriends[friendItemIndex]);
                  } else if (searchTopicViewCount > 0 && index >= topicStartIndex && index <= topicEndIndex) {
                    if (index == topicStartIndex) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 16, left: 16, right: 16),
                        child: Label(
                          '($searchTopicDataCount) ${_localizations.group_chat}',
                          type: LabelType.h3,
                        ),
                      );
                    }
                    return _getTopicItemView(_searchTopics[topicItemIndex]);
                  } else if (searchStrangerViewCount > 0 && index >= strangerStartIndex && index <= strangerEndIndex) {
                    if (index == strangerStartIndex) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 16, left: 16, right: 16),
                        child: Label(
                          '($searchStrangerDataCount) ${_localizations.recent}',
                          type: LabelType.h3,
                        ),
                      );
                    }
                    return _getStrangerItemView(_searchStrangers[strangerItemIndex]);
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
    S _localizations = S.of(Global.appContext);

    return Slidable(
      key: ObjectKey(item),
      direction: Axis.horizontal,
      actionPane: SlidableDrawerActionPane(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ContactItem(
            contact: item,
            onTap: () {
              _onTapContactItem(item);
            },
            bgColor: Colors.transparent,
            bodyTitle: item.displayName,
            bodyDesc: timeFormat(item.updateAt != null ? DateTime.fromMillisecondsSinceEpoch(item.updateAt!) : null),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            tail: Padding(
              padding: const EdgeInsets.only(right: 8, left: 16),
              child: Label(
                item.isMe ? 'Me' : '',
                type: LabelType.bodySmall,
              ),
            ),
          ),
          Divider(height: 1, indent: 74, endIndent: 16),
        ],
      ),
      secondaryActions: [
        IconSlideAction(
          caption: _localizations.delete,
          color: Colors.red,
          icon: Icons.delete,
          onTap: () => {
            ModalDialog.of(Global.appContext).confirm(
              title: _localizations.delete_contact_confirm_title,
              contentWidget: ContactItem(
                contact: item,
                bodyTitle: item.displayName,
                bodyDesc: item.clientAddress,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              ),
              agree: Button(
                width: double.infinity,
                text: _localizations.delete_contact,
                backgroundColor: application.theme.strongColor,
                onPressed: () async {
                  if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
                  await contactCommon.delete(item.id, notify: true);
                },
              ),
              reject: Button(
                width: double.infinity,
                text: _localizations.cancel,
                fontColor: application.theme.fontColor2,
                backgroundColor: application.theme.backgroundLightColor,
                onPressed: () {
                  if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
                },
              ),
            )
          },
        ),
      ],
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
          bodyTitle: item.displayName,
          bodyDesc: timeFormat(item.updateAt != null ? DateTime.fromMillisecondsSinceEpoch(item.updateAt!) : null),
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

  Widget _getTopicItemView(TopicSchema item) {
    S _localizations = S.of(Global.appContext);

    return Slidable(
      key: ObjectKey(item),
      direction: Axis.horizontal,
      actionPane: SlidableDrawerActionPane(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TopicItem(
            topic: item,
            onTap: () {
              _onTapTopicItem(item);
            },
            bgColor: Colors.transparent,
            bodyTitle: item.topicShort,
            bodyDesc: item.topic,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          Divider(
            height: 1,
            indent: 74,
            endIndent: 16,
          ),
        ],
      ),
      secondaryActions: [
        IconSlideAction(
          caption: _localizations.delete,
          color: Colors.red,
          icon: Icons.delete,
          onTap: () => {
            ModalDialog.of(Global.appContext).confirm(
              title: _localizations.confirm_unsubscribe_group,
              contentWidget: TopicItem(
                topic: item,
                bodyTitle: item.topicShort,
                bodyDesc: item.topic,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              agree: Button(
                width: double.infinity,
                text: _localizations.delete,
                backgroundColor: application.theme.strongColor,
                onPressed: () async {
                  if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
                  Loading.show();
                  TopicSchema? deleted = await topicCommon.unsubscribe(item.topic);
                  Loading.dismiss();
                  if (deleted != null) {
                    Toast.show(_localizations.unsubscribed);
                  }
                },
              ),
              reject: Button(
                width: double.infinity,
                text: _localizations.cancel,
                fontColor: application.theme.fontColor2,
                backgroundColor: application.theme.backgroundLightColor,
                onPressed: () {
                  if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
                },
              ),
            )
          },
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/contact/item.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/private_group/item.dart';
import 'package:nmobile/components/text/fixed_text_field.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/components/topic/item.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/chat/messages.dart';
import 'package:nmobile/screens/contact/add.dart';
import 'package:nmobile/screens/contact/home_empty.dart';
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/time.dart';

class ContactHomeScreen extends BaseStateFulWidget {
  static const String routeName = '/contact/home';
  static final String argNavTitle = "nav_title";
  static final String argSelectContact = "select_contact";
  static final String argSelectGroup = "select_group";

  static Future go(BuildContext? context, {String? title, bool selectContact = false, bool selectGroup = false}) {
    if (context == null) return Future.value(null);
    return Navigator.pushNamed(context, routeName, arguments: {
      argNavTitle: title,
      argSelectContact: selectContact,
      argSelectGroup: selectGroup,
    });
  }

  final Map<String, dynamic>? arguments;

  ContactHomeScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _ContactHomeScreenState createState() => _ContactHomeScreenState();
}

class _ContactHomeScreenState extends BaseStateFulWidgetState<ContactHomeScreen> {
  String _navTitle = "";

  bool _selectContact = false;
  bool _selectGroup = false;
  bool _isSelect = false;

  bool _pageLoaded = false;

  StreamSubscription? _addContactSubscription;
  // StreamSubscription? _deleteContactSubscription;
  StreamSubscription? _updateContactSubscription;

  StreamSubscription? _addTopicSubscription;
  // StreamSubscription? _deleteTopicSubscription;
  StreamSubscription? _updateTopicSubscription;

  StreamSubscription? _addGroupSubscription;
  StreamSubscription? _updateGroupSubscription;

  TextEditingController _searchController = TextEditingController();

  List<ContactSchema> _allFriends = <ContactSchema>[];
  /*List<ContactSchema> _allStrangers = <ContactSchema>[];*/
  List<TopicSchema> _allTopics = <TopicSchema>[];
  List<PrivateGroupSchema> _allGroups = <PrivateGroupSchema>[];

  List<ContactSchema> _searchFriends = <ContactSchema>[];
  /*List<ContactSchema> _searchStrangers = <ContactSchema>[];*/
  List<TopicSchema> _searchTopics = <TopicSchema>[];
  List<PrivateGroupSchema> _searchGroups = <PrivateGroupSchema>[];

  @override
  void onRefreshArguments() {
    this._navTitle = widget.arguments?[ContactHomeScreen.argNavTitle] ?? "";
    this._selectContact = widget.arguments?[ContactHomeScreen.argSelectContact] ?? false;
    this._selectGroup = widget.arguments?[ContactHomeScreen.argSelectGroup] ?? false;
    this._isSelect = _selectContact || _selectGroup;
  }

  @override
  void initState() {
    super.initState();
    // contact listen
    _addContactSubscription = contactCommon.addStream.listen((ContactSchema schema) {
      if (schema.type == ContactType.friend) {
        if (_allFriends.indexWhere((element) => element.address == schema.address) < 0) {
          _allFriends.insert(0, schema);
        }
      }
      /* else if (schema.type == ContactType.stranger) {
        _allStrangers.insert(0, schema);
      }*/
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
        if (value.address == event.address) {
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
      /*int strangerIndex = -1;
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
      }*/
      // type
      if ((friendIndex < 0) && (event.type == ContactType.friend)) {
        _allFriends.insert(0, event);
        _searchAction(_searchController.text);
      } /* else if ((strangerIndex < 0) && (event.type == ContactType.stranger)) {
        _allStrangers.insert(0, event);
        _searchAction(_searchController.text);
      }*/
    });

    // topic listen
    _addTopicSubscription = topicCommon.addStream.listen((TopicSchema schema) {
      if (_allTopics.indexWhere((element) => element.topicId == schema.topicId) < 0) {
        _allTopics.insert(0, schema);
        _searchAction(_searchController.text);
      }
    });
    // _deleteTopicSubscription = topicCommon.deleteStream.listen((String topic) {
    //   _allTopics = _allTopics.where((element) => element.topic != topic).toList();
    //   _searchAction(_searchController.text);
    // });
    _updateContactSubscription = topicCommon.updateStream.listen((TopicSchema event) {
      _allTopics = _allTopics.map((e) => e.topicId == event.topicId ? event : e).toList();
      if (!event.joined) {
        _allTopics = _allTopics.where((element) => element.topicId != event.topicId).toList();
      }
      _searchAction(_searchController.text);
    });

    // group listen
    _addGroupSubscription = privateGroupCommon.addGroupStream.listen((PrivateGroupSchema schema) {
      if (_allGroups.indexWhere((element) => element.groupId == schema.groupId) < 0) {
        _allGroups.insert(0, schema);
        _searchAction(_searchController.text);
      }
    });
    _updateGroupSubscription = privateGroupCommon.updateGroupStream.listen((PrivateGroupSchema event) {
      _allGroups = _allGroups.map((e) => e.groupId == event.groupId ? event : e).toList();
      if (!event.joined) {
        _allGroups = _allGroups.where((element) => element.groupId != event.groupId).toList();
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
    _addGroupSubscription?.cancel();
    _updateGroupSubscription?.cancel();
    super.dispose();
  }

  _initData() async {
    int limit = 20;
    // contact
    List<ContactSchema> friends = [];
    for (int offset = 0; true; offset += limit) {
      List<ContactSchema> result = await contactCommon.queryList(type: ContactType.friend, offset: offset, limit: limit);
      friends.addAll(result);
      if (result.length < limit) break;
    }
    friends = (!this._isSelect || this._selectContact) ? friends : [];
    // topic
    List<TopicSchema> topics = [];
    for (int offset = 0; true; offset += limit) {
      List<TopicSchema> result = await topicCommon.queryListJoined(offset: offset, limit: limit);
      topics.addAll(result);
      if (result.length < limit) break;
    }
    topics = (!this._isSelect || this._selectGroup) ? topics : []; // can not move this line to setState
    // group
    List<PrivateGroupSchema> groups = [];
    for (int offset = 0; true; offset += limit) {
      List<PrivateGroupSchema> result = await privateGroupCommon.queryGroupListJoined(offset: offset, limit: limit);
      groups.addAll(result);
      if (result.length < limit) break;
    }
    groups = (!this._isSelect || this._selectGroup) ? groups : []; // can not move this line to setState
    // strangers
    /*List<ContactSchema> strangers = await contactCommon.queryList(contactType: ContactType.stranger, limit: 20)*/;

    setState(() {
      _pageLoaded = true;
      // total
      _allFriends = friends;
      /*_allStrangers = strangers;*/
      _allTopics = topics;
      _allGroups = groups;
      // search
      _searchFriends = _allFriends;
      /*_searchStrangers = _allStrangers;*/
      _searchTopics = _allTopics;
      _searchGroups = _allGroups;
    });

    _searchAction(_searchController.text);
  }

  _searchAction(String? val) {
    if (val == null || val.isEmpty) {
      setState(() {
        _searchFriends = _allFriends;
        /*_searchStrangers = _allStrangers;*/
        _searchTopics = _allTopics;
        _searchGroups = _allGroups;
      });
    } else {
      setState(() {
        /*_searchStrangers = _allStrangers.where((ContactSchema e) => e.displayName.toLowerCase().contains(val.toLowerCase())).toList();*/
        _searchFriends = _allFriends.where((ContactSchema e) => e.displayName.toLowerCase().contains(val.toLowerCase())).toList();
        _searchTopics = _allTopics.where((TopicSchema e) => e.topicId.contains(val)).toList();
        _searchGroups = _allGroups.where((PrivateGroupSchema e) => e.name.contains(val)).toList();
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
    if (this._isSelect) {
      if (Navigator.of(this.context).canPop()) Navigator.pop(this.context, item);
    } else {
      //TopicProfileScreen.go(context, schema: item);
      ChatMessagesScreen.go(context, item);
    }
  }

  _onTapGroupItem(PrivateGroupSchema item) async {
    if (this._isSelect) {
      if (Navigator.of(this.context).canPop()) Navigator.pop(this.context, item);
    } else {
      //GroupProfileScreen.go(context, schema: item);
      ChatMessagesScreen.go(context, item);
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalFriendDataCount = _allFriends.length;
    int totalTopicDataCount = _allTopics.length;
    int totalGroupDataCount = _allGroups.length;
    /*int totalStrangerDataCount = _allStrangers.length;*/

    int totalDataCount = totalFriendDataCount + totalTopicDataCount + totalGroupDataCount; // + totalStrangerDataCount;
    if (totalDataCount <= 0 && _pageLoaded) {
      return ContactHomeEmptyLayout();
    }

    int searchFriendDataCount = _searchFriends.length;
    int searchFriendViewCount = (searchFriendDataCount > 0 ? 1 : 0) + searchFriendDataCount;
    int searchTopicDataCount = _searchTopics.length;
    int searchTopicViewCount = (searchTopicDataCount > 0 ? 1 : 0) + searchTopicDataCount;
    int searchGroupDataCount = _searchGroups.length;
    int searchGroupViewCount = (searchGroupDataCount > 0 ? 1 : 0) + searchGroupDataCount;
    /*int searchStrangerDataCount = _searchStrangers.length;
    int searchStrangerViewCount = (searchStrangerDataCount > 0 ? 1 : 0) + searchStrangerDataCount;*/

    int listItemViewCount = searchFriendViewCount + searchTopicViewCount + searchGroupViewCount; //  + searchStrangerViewCount;

    int friendStartIndex = 0;
    int friendEndIndex = searchFriendViewCount - 1;
    int topicStartIndex = friendEndIndex + 1;
    int topicEndIndex = topicStartIndex + searchTopicViewCount - 1;
    int groupStartIndex = topicEndIndex + 1;
    int groupEndIndex = groupStartIndex + searchGroupViewCount - 1;
    /* int strangerStartIndex = groupEndIndex + 1;
    int strangerEndIndex = strangerStartIndex + searchStrangerViewCount - 1;*/

    return Layout(
      headerColor: application.theme.primaryColor,
      header: Header(
        title: this._navTitle.isEmpty ? Settings.locale((s) => s.contacts, ctx: context) : this._navTitle,
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
                          hintText: Settings.locale((s) => s.search, ctx: context),
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
                  int groupItemIndex = index - searchTopicViewCount - searchFriendViewCount - 1;
                  /*int strangerItemIndex = index - searchGroupViewCount - searchTopicViewCount - searchFriendViewCount - 1;*/

                  if (searchFriendViewCount > 0 && index >= friendStartIndex && index <= friendEndIndex) {
                    if (index == friendStartIndex) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 16, left: 16, right: 16),
                        child: Label(
                          '($searchFriendDataCount) ${Settings.locale((s) => s.friends, ctx: context)}',
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
                          '($searchTopicDataCount) ${Settings.locale((s) => s.group_chat, ctx: context)}',
                          type: LabelType.h3,
                        ),
                      );
                    }
                    return _getTopicItemView(_searchTopics[topicItemIndex]);
                  } else if (searchGroupViewCount > 0 && index >= groupStartIndex && index <= groupEndIndex) {
                    if (index == groupStartIndex) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 16, left: 16, right: 16),
                        child: Label(
                          '($searchGroupDataCount) ${Settings.locale((s) => s.group_chat, ctx: context)}',
                          type: LabelType.h3,
                        ),
                      );
                    }
                    return _getGroupItemView(_searchGroups[groupItemIndex]);
                  }
                  /*else if (searchStrangerViewCount > 0 && index >= strangerStartIndex && index <= strangerEndIndex) {
                    if (index == strangerStartIndex) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 16, left: 16, right: 16),
                        child: Label(
                          '($searchStrangerDataCount) ${Settings.locale((s) => s.recent, ctx: context)}',
                          type: LabelType.h3,
                        ),
                      );
                    }
                    return _getStrangerItemView(_searchStrangers[strangerItemIndex]);
                  }*/
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
            bodyDesc: Time.formatTime(DateTime.fromMillisecondsSinceEpoch(item.updateAt)),
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
          caption: Settings.locale((s) => s.delete, ctx: context),
          color: Colors.red,
          icon: Icons.delete,
          onTap: () => {
            ModalDialog.of(Settings.appContext).confirm(
              title: Settings.locale((s) => s.delete_contact_confirm_title, ctx: context),
              contentWidget: ContactItem(
                contact: item,
                bodyTitle: item.displayName,
                bodyDesc: item.address,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              ),
              agree: Button(
                width: double.infinity,
                text: Settings.locale((s) => s.delete_contact, ctx: context),
                backgroundColor: application.theme.strongColor,
                onPressed: () async {
                  if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
                  await contactCommon.setType(item.address, ContactType.none, notify: true);
                },
              ),
              reject: Button(
                width: double.infinity,
                text: Settings.locale((s) => s.cancel, ctx: context),
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

  /*Widget _getStrangerItemView(ContactSchema item) {
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
          bodyDesc: Time.formatTime(item.updateAt != null ? DateTime.fromMillisecondsSinceEpoch(item.updateAt!) : null),
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
  }*/

  Widget _getTopicItemView(TopicSchema item) {
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
            bodyTitle: item.topicNameShort,
            bodyDesc: item.topicId,
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
          caption: Settings.locale((s) => s.delete, ctx: context),
          color: Colors.red,
          icon: Icons.delete,
          onTap: () => {
            ModalDialog.of(Settings.appContext).confirm(
              title: Settings.locale((s) => s.confirm_unsubscribe_group, ctx: context),
              contentWidget: TopicItem(
                topic: item,
                bodyTitle: item.topicNameShort,
                bodyDesc: item.topicId,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              agree: Button(
                width: double.infinity,
                text: Settings.locale((s) => s.delete, ctx: context),
                backgroundColor: application.theme.strongColor,
                onPressed: () async {
                  if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
                  double? fee = await topicCommon.getTopicSubscribeFee(this.context);
                  if (fee == null) return;
                  Loading.show();
                  TopicSchema? deleted = await topicCommon.unsubscribe(item.topicId, fee: fee, toast: true);
                  Loading.dismiss();
                  if (deleted != null) {
                    Toast.show(Settings.locale((s) => s.unsubscribed, ctx: context));
                  }
                },
              ),
              reject: Button(
                width: double.infinity,
                text: Settings.locale((s) => s.cancel, ctx: context),
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

  Widget _getGroupItemView(PrivateGroupSchema item) {
    return Slidable(
      key: ObjectKey(item),
      direction: Axis.horizontal,
      actionPane: SlidableDrawerActionPane(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrivateGroupItem(
            privateGroup: item,
            onTap: () {
              _onTapGroupItem(item);
            },
            bgColor: Colors.transparent,
            bodyTitle: item.name,
            bodyDesc: item.groupId,
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
          caption: Settings.locale((s) => s.delete, ctx: context),
          color: Colors.red,
          icon: Icons.delete,
          onTap: () => {
            ModalDialog.of(Settings.appContext).confirm(
              title: Settings.locale((s) => s.confirm_unsubscribe_group, ctx: context),
              contentWidget: PrivateGroupItem(
                privateGroup: item,
                bodyTitle: item.name,
                bodyDesc: item.groupId,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              agree: Button(
                width: double.infinity,
                text: Settings.locale((s) => s.delete, ctx: context),
                backgroundColor: application.theme.strongColor,
                onPressed: () async {
                  if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
                  Loading.show();
                  bool success = await privateGroupCommon.quit(item.groupId, toast: true, notify: true);
                  Loading.dismiss();
                  if (success) Toast.show(Settings.locale((s) => s.unsubscribed, ctx: context));
                },
              ),
              reject: Button(
                width: double.infinity,
                text: Settings.locale((s) => s.cancel, ctx: context),
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

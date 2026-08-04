import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/contact/item.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/create_private_group.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/components/layout/chat_topic_search.dart';
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
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/contact_io.dart';
import 'package:nmobile/utils/time.dart';
import 'package:nmobile/utils/util.dart';

import '../../helpers/error.dart';

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

  Future<void> _exportContacts() async {
    try {
      Loading.show();
      String? path = await ContactIO.exportFriendsAsJson();
      Loading.dismiss();
      if (path == null) {
        Toast.show(Settings.locale((s) => s.something_went_wrong, ctx: context));
        return;
      }
      Toast.show(Settings.locale((s) => s.success, ctx: context));
      Util.launchFile(path);
    } catch (e, st) {
      Loading.dismiss();
      handleError(e, st);
      Toast.show(Settings.locale((s) => s.something_went_wrong, ctx: context));
    }
  }

  Future<void> _importContacts() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: Platform.isAndroid ? FileType.any : FileType.custom,
        allowedExtensions: Platform.isAndroid ? null : ["json"],
      );
      if (result == null || result.files.isEmpty) return;
      String? path = result.files.first.path;
      if (path == null) return;
      File picked = File(path);
      if (!path.toLowerCase().endsWith('.json')) {
        if (!mounted) return;
        Toast.show(Settings.locale((s) => s.something_went_wrong, ctx: Settings.appContext));
        return;
      }
      if (!await picked.exists()) {
        if (!mounted) return;
        Toast.show(Settings.locale((s) => s.file_not_exist, ctx: Settings.appContext));
        return;
      }
      Loading.show();
      int imported = await ContactIO.importContactsFromJsonFile(picked);
      Loading.dismiss();
      if (!mounted) return;
      Toast.show('${Settings.locale((s) => s.success, ctx: Settings.appContext)} ($imported)');
    } catch (e, st) {
      Loading.dismiss();
      handleError(e, st);
      if (!mounted) return;
      Toast.show(Settings.locale((s) => s.something_went_wrong, ctx: Settings.appContext));
    }
  }

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
      if (_allTopics.indexWhere((element) => element.topicId == event.topicId) < 0) {
        _allTopics.insert(0, event);
        _searchAction(_searchController.text);
        return;
      }
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
    final limit = 20;
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
        title: this._navTitle.isEmpty ? Settings.locale((s) => s.new_chat, ctx: context) : this._navTitle,
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
          ),
          PopupMenuButton<int>(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            icon: Asset.iconSvg('more', color: application.theme.backgroundLightColor, width: 24),
            onSelected: (int result) {
              if (result == 0) {
                _exportContacts();
              } else if (result == 1) {
                _importContacts();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
              PopupMenuItem<int>(
                value: 0,
                child: Label(Settings.locale((s) => s.export_contacts, ctx: context), type: LabelType.display),
              ),
              PopupMenuItem<int>(
                value: 1,
                child: Label(Settings.locale((s) => s.import_contacts, ctx: context), type: LabelType.display),
              ),
            ],
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
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
            ),
            SliverToBoxAdapter(
              child: _searchController.text.isNotEmpty ? _buildSearchByIdMenuBar() : _buildActionMenuBar(),
            ),
            totalDataCount <= 0 && _pageLoaded
                ? SliverPadding(
                    padding: EdgeInsets.only(top: 40),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Asset.image("contact/no-contact.png", width: 200, height: 200),
                          SizedBox(height: 30),
                          Column(
                            children: <Widget>[
                              Label(
                                Settings.locale((s) => s.contact_no_contact_title, ctx: context),
                                type: LabelType.h2,
                                textAlign: TextAlign.center,
                                maxLines: 10,
                              ),
                              SizedBox(height: 50),
                              Label(
                                Settings.locale((s) => s.contact_no_contact_desc, ctx: context),
                                type: LabelType.bodySmall,
                                textAlign: TextAlign.center,
                                softWrap: true,
                                maxLines: 10,
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverToBoxAdapter(),
            SliverPadding(
              padding: EdgeInsets.only(bottom: 72),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    int friendItemIndex = index - 1;
                    int topicItemIndex = index - searchFriendViewCount - 1;
                    int groupItemIndex = index - searchTopicViewCount - searchFriendViewCount - 1;

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
                    return SizedBox.shrink();
                  },
                  childCount: listItemViewCount,
                ),
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
      endActionPane: ActionPane(
        motion: ScrollMotion(),
        extentRatio: 0.25,
        children: [
          CustomSlidableAction(
            onPressed: (BuildContext context) {
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
              );
            },
            backgroundColor: Colors.red,
            foregroundColor: application.theme.fontLightColor,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.delete,
                  color: application.theme.fontLightColor,
                  size: 24,
                ),
                Label(
                  Settings.locale((s) => s.delete, ctx: context),
                  color: application.theme.fontLightColor,
                  type: LabelType.bodyRegular,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getTopicItemView(TopicSchema item) {
    return Slidable(
      key: ObjectKey(item),
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
      endActionPane: ActionPane(
        motion: ScrollMotion(),
        extentRatio: 0.25,
        children: [
          CustomSlidableAction(
            onPressed: (BuildContext context) {
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
              );
            },
            backgroundColor: Colors.red,
            foregroundColor: application.theme.fontLightColor,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.delete,
                  color: application.theme.fontLightColor,
                  size: 24,
                ),
                Label(
                  Settings.locale((s) => s.delete, ctx: context),
                  color: application.theme.fontLightColor,
                  type: LabelType.bodyRegular,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getGroupItemView(PrivateGroupSchema item) {
    return Slidable(
      key: ObjectKey(item),
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
      endActionPane: ActionPane(
        motion: ScrollMotion(),
        extentRatio: 0.25,
        children: [
          CustomSlidableAction(
            onPressed: (BuildContext context) {
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
              );
            },
            backgroundColor: Colors.red,
            foregroundColor: application.theme.fontLightColor,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.delete,
                  color: application.theme.fontLightColor,
                  size: 24,
                ),
                Label(
                  Settings.locale((s) => s.delete, ctx: context),
                  color: application.theme.fontLightColor,
                  type: LabelType.bodyRegular,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _buttonStyle({bool topRadius = true, bool botRadius = true, double topPad = 12, double botPad = 12}) {
    return ButtonStyle(
      backgroundColor: MaterialStateProperty.resolveWith((state) => application.theme.backgroundLightColor),
      padding: MaterialStateProperty.resolveWith((states) => EdgeInsets.only(left: 16, right: 16, top: topPad, bottom: botPad)),
      shape: MaterialStateProperty.resolveWith(
        (states) => RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: topRadius ? Radius.circular(12) : Radius.zero,
            bottom: botRadius ? Radius.circular(12) : Radius.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildActionMenuBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          TextButton(
            style: _buttonStyle(topRadius: true, botRadius: false, topPad: 15, botPad: 15),
            onPressed: () async {
              ContactSchema? validatedContact;

              String? address = await BottomDialog.of(Settings.appContext).showInput(
                title: Settings.locale((s) => s.new_whisper, ctx: context),
                inputTip: Settings.locale((s) => s.send_to, ctx: context),
                inputHint: Settings.locale((s) => s.enter_or_select_a_user_pubkey, ctx: context),
                contactSelect: true,
                asyncValidator: (value) async {
                  if (value.isEmpty) {
                    return null;
                  }

                  validatedContact = await contactCommon.resolveByAddress(value, canAdd: true);
                  if (validatedContact == null) {
                    return Settings.locale((s) => s.tip_address_not_found, ctx: context);
                  }
                  return null;
                },
              );

              if (address != null && address.isNotEmpty && validatedContact != null) {
                await ChatMessagesScreen.go(context, validatedContact!);
              }
            },
            child: Row(
              children: <Widget>[
                Asset.iconSvg('user', color: application.theme.primaryColor, width: 24),
                SizedBox(width: 10),
                Label(
                  Settings.locale((s) => s.new_whisper, ctx: context),
                  type: LabelType.bodyRegular,
                  color: application.theme.fontColor1,
                ),
                Spacer(),
                Asset.iconSvg(
                  'right',
                  width: 24,
                  color: application.theme.fontColor2,
                ),
              ],
            ),
          ),
          Divider(height: 0, color: application.theme.dividerColor),
          TextButton(
            style: _buttonStyle(topRadius: false, botRadius: false, topPad: 15, botPad: 15),
            onPressed: () {
              BottomDialog.of(Settings.appContext).showWithTitle(
                height: Settings.screenHeight() * 0.8,
                title: Settings.locale((s) => s.create_channel, ctx: context),
                child: ChatTopicSearchLayout(),
              );
            },
            child: Row(
              children: <Widget>[
                Asset.iconSvg('group', color: application.theme.primaryColor, width: 24),
                SizedBox(width: 10),
                Label(
                  Settings.locale((s) => s.new_public_group, ctx: context),
                  type: LabelType.bodyRegular,
                  color: application.theme.fontColor1,
                ),
                Spacer(),
                Asset.iconSvg(
                  'right',
                  width: 24,
                  color: application.theme.fontColor2,
                ),
              ],
            ),
          ),
          Divider(height: 0, color: application.theme.dividerColor),
          TextButton(
            style: _buttonStyle(topRadius: false, botRadius: true, topPad: 15, botPad: 15),
            onPressed: () {
              BottomDialog.of(Settings.appContext).showWithTitle(
                height: 300,
                title: Settings.locale((s) => s.create_private_group, ctx: context),
                child: CreatePrivateGroup(),
              );
            },
            child: Row(
              children: <Widget>[
                Asset.iconSvg('lock', color: application.theme.primaryColor, width: 24),
                SizedBox(width: 10),
                Label(
                  Settings.locale((s) => s.new_private_group, ctx: context),
                  type: LabelType.bodyRegular,
                  color: application.theme.fontColor1,
                ),
                Spacer(),
                Asset.iconSvg(
                  'right',
                  width: 24,
                  color: application.theme.fontColor2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchByIdMenuBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextButton(
        style: _buttonStyle(topRadius: true, botRadius: true, topPad: 15, botPad: 15),
        onPressed: () async {
          String searchText = _searchController.text.trim();
          if (searchText.isEmpty) {
            Toast.show(Settings.locale((s) => s.search, ctx: context));
            return;
          }

          Loading.show();
          try {
            ContactSchema? validatedContact = await contactCommon.resolveByAddress(searchText, canAdd: true);
            Loading.dismiss();

            if (validatedContact == null) {
              if (!mounted) return;
              Toast.show(Settings.locale((s) => s.tip_address_not_found, ctx: context));
              return;
            }

            if (!mounted) return;
            await ChatMessagesScreen.go(context, validatedContact);
          } catch (e, st) {
            Loading.dismiss();
            handleError(e, st);
            if (!mounted) return;
            Toast.show(Settings.locale((s) => s.something_went_wrong, ctx: context));
          }
        },
        child: Row(
          children: <Widget>[
            Asset.iconSvg('search', color: application.theme.primaryColor, width: 24),
            SizedBox(width: 10),
            Expanded(
              child: Label(
                '${Settings.locale((s) => s.search, ctx: context)} "${_searchController.text}"',
                type: LabelType.bodyRegular,
                color: application.theme.fontColor1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Asset.iconSvg(
              'right',
              width: 24,
              color: application.theme.fontColor2,
            ),
          ],
        ),
      ),
    );
  }
}

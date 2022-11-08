import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/private_group/header.dart';
import 'package:nmobile/components/private_group/subscriber_item.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/validate.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/private_group.dart';
import 'package:nmobile/schema/private_group_item.dart';
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';

class PrivateGroupSubscribersScreen extends BaseStateFulWidget {
  static const String routeName = '/privateGroup/members';
  static final String argPrivateGroupSchema = "privateGroupSchema";
  static final String argPrivateGroupId = "privateGroupId";

  static Future go(BuildContext? context, {PrivateGroupSchema? schema, String? groupId}) {
    if (context == null) return Future.value(null);
    if ((schema == null) && (groupId == null)) return Future.value(null);
    return Navigator.pushNamed(context, routeName, arguments: {
      argPrivateGroupSchema: schema,
      argPrivateGroupId: groupId,
    });
  }

  final Map<String, dynamic>? arguments;

  PrivateGroupSubscribersScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _PrivateGroupSubscribersScreenState createState() => _PrivateGroupSubscribersScreenState();
}

class _PrivateGroupSubscribersScreenState extends BaseStateFulWidgetState<PrivateGroupSubscribersScreen> {
  StreamSubscription? _updatePrivateGroupSubscription;
  StreamSubscription? _addPrivateGroupItemStreamSubscription;
  StreamSubscription? _updatePrivateGroupItemStreamSubscription;

  PrivateGroupSchema? _privateGroup;
  bool _isOwner = false;
  ScrollController _scrollController = ScrollController();
  bool _moreLoading = false;
  List<PrivateGroupItemSchema> _members = [];

  @override
  void onRefreshArguments() {
    _refreshPrivateGroupSchema();
  }

  @override
  initState() {
    super.initState();
    // listen
    _updatePrivateGroupSubscription = privateGroupCommon.updateGroupStream.where((event) => _privateGroup?.groupId == event.groupId).listen((PrivateGroupSchema event) {
      setState(() {
        _privateGroup = event;
        _isOwner = privateGroupCommon.isOwner(_privateGroup?.ownerPublicKey, clientCommon.getPublicKey());
      });
    });
    _addPrivateGroupItemStreamSubscription = privateGroupCommon.addGroupItemStream.where((event) => _privateGroup?.groupId == event.groupId).listen((PrivateGroupItemSchema schema) {
      _members.add(schema);
      setState(() {});
    });
    _updatePrivateGroupItemStreamSubscription = privateGroupCommon.updateGroupItemStream.where((event) => _privateGroup?.groupId == event.groupId).listen((PrivateGroupItemSchema event) {
      int index = _members.indexWhere((element) => element.id == event.id);
      if ((index >= 0) && (index < _members.length)) {
        if ((event.permission ?? 0) <= PrivateGroupItemPerm.none) {
          _members.removeAt(index);
        } else {
          _members[index] = event;
        }
      } else {
        if ((event.permission ?? 0) > PrivateGroupItemPerm.none) {
          _members.add(event);
        }
      }
      setState(() {});
    });

    // scroll
    _scrollController.addListener(() {
      if (_moreLoading) return;
      double offsetFromBottom = _scrollController.position.maxScrollExtent - _scrollController.position.pixels;
      if (offsetFromBottom < 50) {
        _moreLoading = true;
        _getDataSubscribers(false).then((v) {
          _moreLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _updatePrivateGroupSubscription?.cancel();
    _addPrivateGroupItemStreamSubscription?.cancel();
    _updatePrivateGroupItemStreamSubscription?.cancel();
    super.dispose();
  }

  _refreshPrivateGroupSchema({PrivateGroupSchema? schema}) async {
    PrivateGroupSchema? privateGroupSchema = widget.arguments?[PrivateGroupSubscribersScreen.argPrivateGroupSchema];
    String? groupId = widget.arguments?[PrivateGroupSubscribersScreen.argPrivateGroupId];
    if (schema != null) {
      this._privateGroup = schema;
    } else if (privateGroupSchema != null && privateGroupSchema.id != 0) {
      this._privateGroup = privateGroupSchema;
    } else if (groupId != null) {
      this._privateGroup = await privateGroupCommon.queryGroup(groupId);
    }
    if (this._privateGroup == null) return;
    _isOwner = privateGroupCommon.isOwner(_privateGroup?.ownerPublicKey, clientCommon.getPublicKey());

    setState(() {});

    _getDataSubscribers(true);
  }

  _getDataSubscribers(bool refresh) async {
    int _offset = 0;
    if (refresh) {
      _members = [];
    } else {
      _offset = _members.length;
    }

    String? selfPubKey = clientCommon.getPublicKey();
    PrivateGroupItemSchema? owner = await privateGroupCommon.queryGroupItem(_privateGroup?.groupId, _privateGroup?.ownerPublicKey);
    PrivateGroupItemSchema? self = await privateGroupCommon.queryGroupItem(_privateGroup?.groupId, selfPubKey);

    List<PrivateGroupItemSchema> members = await privateGroupCommon.queryMembers(_privateGroup?.groupId, offset: _offset, limit: 20);
    members.removeWhere((element) => ((element.permission ?? 0) <= PrivateGroupItemPerm.none) || (element.invitee == owner?.invitee) || (element.invitee == self?.invitee));

    if (refresh) {
      if (owner != null) members.add(owner);
      if (!_isOwner && (self != null) && ((self.permission ?? 0) > PrivateGroupItemPerm.none)) members.add(self);
    }
    members.sort((a, b) => b.invitee == _privateGroup?.ownerPublicKey ? 1 : (b.invitee == selfPubKey ? 1 : 0));
    _members = refresh ? members : _members + members;

    setState(() {});
  }

  _invitee() async {
    if (_privateGroup == null) return;
    String? address = await BottomDialog.of(Global.appContext).showInput(
      title: Global.locale((s) => s.invite_members),
      inputTip: Global.locale((s) => s.send_to),
      inputHint: Global.locale((s) => s.enter_or_select_a_user_pubkey),
      validator: Validator.of(context).identifierNKN(),
      contactSelect: true,
    );
    if (Validate.isNknChatIdentifierOk(address)) {
      bool success = await privateGroupCommon.invitee(_privateGroup?.groupId, address, toast: true);
      if (success) Toast.show(Global.locale((s) => s.invite_and_send_success));
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> actions = <Widget>[];
    if (_isOwner) {
      actions.add(Padding(
        padding: const EdgeInsets.only(right: 8),
        child: IconButton(
          icon: Asset.image('chat/invisit-blue.png', width: 24, color: Colors.white),
          onPressed: () {
            _invitee();
          },
        ),
      ));
    }
    return Layout(
      headerColor: application.theme.backgroundColor4,
      clipAlias: false,
      header: Header(
        backgroundColor: application.theme.backgroundColor4,
        title: Global.locale((s) => s.channel_members, ctx: context),
        actions: actions,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Center(
              child: _privateGroup != null
                  ? PrivateGroupHeader(
                      privateGroup: _privateGroup!,
                      avatarRadius: 36,
                      dark: false,
                      body: Builder(
                        builder: (BuildContext context) {
                          if (privateGroupCommon.isOwner(_privateGroup?.ownerPublicKey, clientCommon.getPublicKey()) == true) {
                            return Container(
                              padding: EdgeInsets.only(left: 3),
                              child: Label(
                                '${_privateGroup?.count ?? '--'} ' + Global.locale((s) => s.members, ctx: context),
                                type: LabelType.bodyRegular,
                                color: application.theme.successColor,
                              ),
                            );
                          } else {
                            return Label(
                              '${_privateGroup?.count ?? '--'} ' + Global.locale((s) => s.members, ctx: context),
                              type: LabelType.bodyRegular,
                              color: application.theme.successColor,
                            );
                          }
                        },
                      ),
                    )
                  : SizedBox.shrink(),
            ),
          ),
          Expanded(
            child: _subscriberListView(),
          ),
        ],
      ),
    );
  }

  Widget _subscriberListView() {
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 72),
      controller: _scrollController,
      itemCount: _members.length,
      itemBuilder: (BuildContext context, int index) {
        if (index < 0 || index >= _members.length) return SizedBox.shrink();
        var _member = _members[index];
        return Column(
          children: [
            SubscriberItem(
              privateGroup: _privateGroup,
              privateGroupItem: _member,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              onTap: (ContactSchema? contact) {
                ContactProfileScreen.go(context, schema: contact, clientAddress: _member.invitee);
              },
            ),
            Divider(color: application.theme.dividerColor, height: 0, indent: 70, endIndent: 12),
          ],
        );
      },
    );
  }
}

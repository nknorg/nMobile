import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/topic/header.dart';
import 'package:nmobile/components/topic/subscriber_item.dart';
import 'package:nmobile/helpers/validate.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/utils/asset.dart';

class TopicSubscribersScreen extends BaseStateFulWidget {
  static const String routeName = '/topic/members';
  static final String argTopicSchema = "topic_schema";
  static final String argTopicId = "topic_id";

  static Future go(BuildContext? context, {TopicSchema? schema, String? topicId}) {
    if (context == null) return Future.value(null);
    if (schema == null && (topicId == null || topicId.isEmpty)) return Future.value(null);
    return Navigator.pushNamed(context, routeName, arguments: {
      argTopicSchema: schema,
      argTopicId: topicId,
    });
  }

  final Map<String, dynamic>? arguments;

  TopicSubscribersScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _TopicSubscribersScreenState createState() => _TopicSubscribersScreenState();
}

class _TopicSubscribersScreenState extends BaseStateFulWidgetState<TopicSubscribersScreen> {
  StreamSubscription? _updateTopicSubscription;
  // StreamSubscription? _deleteTopicSubscription;
  StreamSubscription? _addSubscriberSubscription;
  // StreamSubscription? _deleteSubscriberSubscription;
  StreamSubscription? _updateSubscriberSubscription;

  TopicSchema? _topic;

  ScrollController _scrollController = ScrollController();
  bool _moreLoading = false;
  List<SubscriberSchema> _subscriberList = [];

  int? _invitedSendCount;
  int? _invitedReceiptCount;
  int? _subscriberCount;

  // bool isPopIng = false;

  @override
  void onRefreshArguments() {
    _refreshTopicSchema();
  }

  @override
  initState() {
    super.initState();
    // topic listen
    // isPopIng = false;
    _updateTopicSubscription = topicCommon.updateStream.where((event) => event.topicId == _topic?.topicId).listen((TopicSchema event) {
      // if (!event.joined && !isPopIng) {
      //   isPopIng = true;
      //   if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
      //   return;
      // }
      setState(() {
        _topic = event;
      });
      // _refreshMembersCount(); // await
    });
    // _deleteTopicSubscription = topicCommon.deleteStream.where((event) => event == _topicSchema?.topic).listen((String topic) {
    //   if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
    // });

    // subscriber listen
    _addSubscriberSubscription = subscriberCommon.addStream.where((event) => event.topicId == _topic?.topicId).listen((SubscriberSchema schema) {
      if (_subscriberList.indexWhere((element) => (element.topicId == schema.topicId) && (element.contactAddress == schema.contactAddress)) < 0) {
        _subscriberList.add(schema);
        _showSubscriberList();
      }
    });
    // _deleteSubscriberSubscription = subscriberCommon.deleteStream.listen((int subscriberId) {
    //   setState(() {
    //     _subscriberList = _subscriberList.where((element) => element.id != subscriberId).toList();
    //   });
    // });
    _updateSubscriberSubscription = subscriberCommon.updateStream.where((event) => event.topicId == _topic?.topicId).listen((SubscriberSchema event) {
      int index = _subscriberList.indexWhere((element) => (element.topicId == event.topicId) && (element.contactAddress == event.contactAddress));
      if ((index >= 0) && (index < _subscriberList.length)) {
        _subscriberList[index] = event;
      } else {
        _subscriberList.add(event);
      }
      _showSubscriberList();
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
    _updateTopicSubscription?.cancel();
    // _deleteTopicSubscription?.cancel();
    _addSubscriberSubscription?.cancel();
    // _deleteSubscriberSubscription?.cancel();
    _updateSubscriberSubscription?.cancel();
    super.dispose();
  }

  _refreshTopicSchema({TopicSchema? schema}) async {
    TopicSchema? topicSchema = widget.arguments?[TopicSubscribersScreen.argTopicSchema];
    String? topicId = widget.arguments?[TopicSubscribersScreen.argTopicId];
    if (schema != null) {
      this._topic = schema;
    } else if (topicSchema != null) {
      this._topic = topicSchema;
    } else if (topicId?.isNotEmpty == true) {
      this._topic = await topicCommon.query(topicId);
    }
    if (this._topic == null) return;
    setState(() {});

    // exist
    topicCommon.query(this._topic?.topicId).then((TopicSchema? exist) async {
      if (exist != null) return;
      TopicSchema? added = await topicCommon.add(this._topic, notify: true);
      if (added == null) return;
      setState(() {
        this._topic = added;
      });
      // check
      topicCommon.checkExpireAndSubscribe(this._topic?.topicId, refreshSubscribers: true).then((value) {
        _getDataSubscribers(true);
      }); // await
    });

    // topic
    _refreshMembersCount(); // await

    // subscribers
    subscriberCommon.refreshSubscribers(this._topic?.topicId, _topic?.ownerPubKey, meta: this._topic?.isPrivate == true).then((value) async {
      await topicCommon.setLastRefreshSubscribersAt(this._topic?.topicId, notify: true); // await
      await _refreshMembersCount(); // await
      _getDataSubscribers(true); // await
    });
    _getDataSubscribers(true); // await
  }

  _refreshMembersCount() async {
    int count = await subscriberCommon.getSubscribersCount(_topic?.topicId, _topic?.isPrivate == true);
    if (_topic?.count != count) {
      await topicCommon.setCount(_topic?.topicId, count, notify: true);
    }
    _invitedSendCount = await subscriberCommon.queryCountByTopicId(_topic?.topicId, status: SubscriberStatus.InvitedSend);
    _invitedReceiptCount = await subscriberCommon.queryCountByTopicId(_topic?.topicId, status: SubscriberStatus.InvitedReceipt);
    _subscriberCount = await subscriberCommon.queryCountByTopicId(_topic?.topicId, status: SubscriberStatus.Subscribed);
    setState(() {});
  }

  _getDataSubscribers(bool refresh) async {
    int _offset = 0;
    if (refresh) {
      _subscriberList = [];
    } else {
      _offset = _subscriberList.length;
    }
    bool isOwner = _topic?.isOwner(clientCommon.address) ?? false;
    int? status = isOwner ? null : SubscriberStatus.Subscribed;
    var subscribers = await subscriberCommon.queryListByTopicId(this._topic?.topicId, status: status, offset: _offset, limit: 20);
    if (refresh) subscribers.sort((a, b) => (_topic?.isPrivate == true) ? (_topic?.isOwner(b.contactAddress) == true ? 1 : (b.contactAddress == clientCommon.address ? 1 : -1)) : (b.contactAddress == clientCommon.address ? 1 : -1));
    _subscriberList = refresh ? subscribers : _subscriberList + subscribers; // maybe addStream
    _showSubscriberList();
  }

  _showSubscriberList() {
    bool isOwner = _topic?.isOwner(clientCommon.address) ?? false;
    setState(() {
      if (isOwner) {
        _subscriberList = _subscriberList.where((element) => element.status != SubscriberStatus.None).toList();
      } else {
        _subscriberList = _subscriberList.where((element) => element.status == SubscriberStatus.Subscribed).toList();
      }
    });
  }

  _invitee() async {
    if (_topic == null) return;
    String? address = await BottomDialog.of(Settings.appContext).showInput(
      title: Settings.locale((s) => s.invite_members),
      inputTip: Settings.locale((s) => s.send_to),
      inputHint: Settings.locale((s) => s.enter_or_select_a_user_pubkey),
      validator: Validator.of(context).identifierNKN(),
      contactSelect: true,
    );
    if (Validate.isNknChatIdentifierOk(address)) {
      double? fee = 0.0;
      if (_topic?.isPrivate == true) {
        fee = await topicCommon.getTopicSubscribeFee(this.context);
        if (fee == null) return;
      }
      await topicCommon.invitee(
        _topic?.topicId,
        _topic?.isPrivate == true,
        _topic?.isOwner(clientCommon.address) == true,
        address,
        fee: fee,
        toast: true,
        sendMsg: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String invitedCount = (_invitedSendCount != null && _invitedReceiptCount != null) ? ((_invitedSendCount ?? 0) + _invitedReceiptCount!).toString() : "--";
    String joinedCount = _subscriberCount?.toString() ?? "--";
    String inviteContent = '$invitedCount' + Settings.locale((s) => s.members, ctx: context) + ':' + Settings.locale((s) => s.invitation_sent, ctx: context);
    String joinedContent = '$joinedCount' + Settings.locale((s) => s.members, ctx: context) + ':' + Settings.locale((s) => s.joined_channel, ctx: context);

    return Layout(
      headerColor: application.theme.backgroundColor4,
      clipAlias: false,
      header: Header(
        backgroundColor: application.theme.backgroundColor4,
        title: Settings.locale((s) => s.channel_members, ctx: context),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Asset.image('chat/invisit-blue.png', width: 24, color: Colors.white),
              onPressed: () {
                _invitee();
              },
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: _topic != null
                ? Center(
                    child: TopicHeader(
                      topic: _topic!,
                      avatarRadius: 36,
                      dark: false,
                      body: Builder(
                        builder: (BuildContext context) {
                          if (_topic?.isOwner(clientCommon.address) == true) {
                            return Container(
                              padding: EdgeInsets.only(left: 3),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Label(
                                    inviteContent,
                                    textAlign: TextAlign.start,
                                    type: LabelType.bodyRegular,
                                    color: application.theme.successColor,
                                  ),
                                  Label(
                                    joinedContent,
                                    textAlign: TextAlign.start,
                                    type: LabelType.bodyRegular,
                                    color: application.theme.successColor,
                                  ),
                                ],
                              ),
                            );
                          } else {
                            return Label(
                              '${_topic?.count ?? '--'} ' + Settings.locale((s) => s.members, ctx: context),
                              type: LabelType.bodyRegular,
                              color: application.theme.successColor,
                            );
                          }
                        },
                      ),
                    ),
                  )
                : SizedBox.shrink(),
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
      itemCount: _subscriberList.length,
      itemBuilder: (BuildContext context, int index) {
        if (index < 0 || index >= _subscriberList.length) return SizedBox.shrink();
        var _subscriber = _subscriberList[index];
        return Column(
          children: [
            SubscriberItem(
              subscriber: _subscriber,
              topic: _topic,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              onTap: (ContactSchema? contact) {
                ContactProfileScreen.go(context, schema: contact, address: _subscriber.contactAddress);
              },
            ),
            Divider(color: application.theme.dividerColor, height: 0, indent: 70, endIndent: 12),
          ],
        );
      },
    );
  }
}

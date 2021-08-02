import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/topic/header.dart';
import 'package:nmobile/components/topic/subscriber_item.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/validation.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/contact/profile.dart';
import 'package:nmobile/utils/asset.dart';
import 'package:nmobile/utils/logger.dart';

class TopicSubscribersScreen extends BaseStateFulWidget {
  static const String routeName = '/topic/members';
  static final String argTopicSchema = "topic_schema";
  static final String argTopicId = "topic_id";
  static final String argTopicTopic = "topic_topic";

  static Future go(BuildContext context, {TopicSchema? schema, int? topicId, String? topic}) {
    logger.d("TopicMembersScreen - go - id:$topicId - topic:$topic - schema:$schema");
    if (schema == null && (topicId == null || topicId == 0)) return Future.value(null);
    return Navigator.pushNamed(context, routeName, arguments: {
      argTopicSchema: schema,
      argTopicId: topicId,
      argTopicTopic: topic,
    });
  }

  final Map<String, dynamic>? arguments;

  TopicSubscribersScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _TopicSubscribersScreenState createState() => _TopicSubscribersScreenState();
}

class _TopicSubscribersScreenState extends BaseStateFulWidgetState<TopicSubscribersScreen> {
  StreamSubscription? _updateTopicSubscription;
  StreamSubscription? _deleteTopicSubscription;
  StreamSubscription? _addSubscriberSubscription;
  StreamSubscription? _deleteSubscriberSubscription;
  StreamSubscription? _updateSubscriberSubscription;

  TopicSchema? _topicSchema;

  ScrollController _scrollController = ScrollController();
  bool _moreLoading = false;
  List<SubscriberSchema> _subscriberList = [];

  int? _invitedSendCount;
  int? _invitedReceiptCount;
  int? _subscriberCount;

  @override
  void onRefreshArguments() {
    _refreshTopicSchema();
  }

  @override
  initState() {
    super.initState();
    // topic listen
    _updateTopicSubscription = topicCommon.updateStream.where((event) => event.id == _topicSchema?.id).listen((TopicSchema event) {
      setState(() {
        _topicSchema = event;
      });
      _refreshMembersCount(); // await
    });
    _deleteTopicSubscription = topicCommon.deleteStream.where((event) => event == _topicSchema?.topic).listen((String topic) {
      Navigator.pop(this.context);
    });

    // subscriber listen
    _addSubscriberSubscription = subscriberCommon.addStream.listen((SubscriberSchema schema) {
      setState(() {
        _subscriberList.add(schema);
      });
    });
    _deleteSubscriberSubscription = subscriberCommon.deleteStream.listen((int subscriberId) {
      setState(() {
        _subscriberList = _subscriberList.where((element) => element.id != subscriberId).toList();
      });
    });
    _updateSubscriberSubscription = subscriberCommon.updateStream.listen((SubscriberSchema event) {
      setState(() {
        _subscriberList = _subscriberList.map((e) => e.id == event.id ? event : e).toList();
      });
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
    _deleteTopicSubscription?.cancel();
    _addSubscriberSubscription?.cancel();
    _deleteSubscriberSubscription?.cancel();
    _updateSubscriberSubscription?.cancel();
    super.dispose();
  }

  _refreshTopicSchema({TopicSchema? schema}) async {
    TopicSchema? topicSchema = widget.arguments![TopicSubscribersScreen.argTopicSchema];
    int? topicId = widget.arguments![TopicSubscribersScreen.argTopicId];
    String? topicName = widget.arguments![TopicSubscribersScreen.argTopicTopic];
    if (schema != null) {
      this._topicSchema = schema;
    } else if (topicSchema != null && topicSchema.id != 0) {
      this._topicSchema = topicSchema;
    } else if (topicId != null && topicId != 0) {
      this._topicSchema = await topicCommon.query(topicId);
    } else if (topicName?.isNotEmpty == true) {
      this._topicSchema = await topicCommon.queryByTopic(topicName);
    }
    if (this._topicSchema == null) return;
    setState(() {});

    // exist
    topicCommon.queryByTopic(this._topicSchema?.topic).then((TopicSchema? exist) async {
      if (exist != null) return;
      TopicSchema? added = await topicCommon.add(this._topicSchema, notify: true, checkDuplicated: false);
      if (added == null) return;
      setState(() {
        this._topicSchema = added;
      });
      // check
      topicCommon.checkExpireAndSubscribe(this._topicSchema?.topic, refreshSubscribers: true).then((value) {
        _getDataSubscribers(true);
      }); // await
    });

    // topic
    _refreshMembersCount(); // await

    // subscribers
    subscriberCommon.refreshSubscribers(this._topicSchema?.topic, meta: this._topicSchema?.isPrivate == true).then((value) {
      _getDataSubscribers(true);
    });
    _getDataSubscribers(true);
  }

  _refreshMembersCount() async {
    int count = await subscriberCommon.getSubscribersCount(_topicSchema?.topic, _topicSchema?.isPrivate == true);
    if (_topicSchema?.count != count) {
      await topicCommon.setCount(_topicSchema?.id, count, notify: true);
    }
    _invitedSendCount = await subscriberCommon.queryCountByTopic(_topicSchema?.topic, status: SubscriberStatus.InvitedSend);
    _invitedReceiptCount = await subscriberCommon.queryCountByTopic(_topicSchema?.topic, status: SubscriberStatus.InvitedReceipt);
    _subscriberCount = await subscriberCommon.queryCountByTopic(_topicSchema?.topic, status: SubscriberStatus.Subscribed);
    setState(() {});
  }

  _getDataSubscribers(bool refresh) async {
    int _offset = 0;
    if (refresh) {
      _subscriberList = [];
    } else {
      _offset = _subscriberList.length;
    }
    var messages = await subscriberCommon.queryListByTopic(this._topicSchema?.topic, offset: _offset, limit: 20);
    messages.sort((a, b) => (_topicSchema?.isPrivate == true) ? (_topicSchema?.isOwner(b.clientAddress) == true ? 1 : (b.clientAddress == clientCommon.address ? 1 : -1)) : (b.clientAddress == clientCommon.address ? 1 : -1));
    setState(() {
      _subscriberList = refresh ? messages : _subscriberList + messages; // maybe addStream
    });
  }

  _invitee() async {
    if (_topicSchema == null) return;
    String? address = await BottomDialog.of(context).showInput(
      title: S.of(context).invite_members,
      inputTip: S.of(context).send_to,
      inputHint: S.of(context).enter_or_select_a_user_pubkey,
      validator: Validator.of(context).identifierNKN(),
      contactSelect: true,
    );
    Loading.show();
    await topicCommon.invitee(
      _topicSchema?.topic,
      _topicSchema?.isPrivate == true,
      _topicSchema?.isOwner(clientCommon.address) == true,
      address,
    );
    Loading.dismiss();
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(this.context);

    String invitedCount = (_invitedSendCount != null && _invitedReceiptCount != null) ? (_invitedSendCount! + _invitedReceiptCount!).toString() : "--";
    String joinedCount = _subscriberCount?.toString() ?? "--";
    String inviteContent = '$invitedCount' + _localizations.members + ':' + _localizations.invitation_sent;
    String joinedContent = '$joinedCount' + _localizations.members + ':' + _localizations.joined_channel;

    return Layout(
      headerColor: application.theme.backgroundColor4,
      clipAlias: false,
      header: Header(
        backgroundColor: application.theme.backgroundColor4,
        title: _localizations.channel_members,
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
            child: _topicSchema != null
                ? Center(
                    child: TopicHeader(
                      topic: _topicSchema!,
                      avatarRadius: 36,
                      dark: false,
                      body: Builder(
                        builder: (BuildContext context) {
                          if (_topicSchema?.isOwner(clientCommon.address) == true) {
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
                              '${_topicSchema?.count ?? '--'} ' + _localizations.members,
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
        var _subscriber = _subscriberList[index];
        return Column(
          children: [
            SubscriberItem(
              subscriber: _subscriber,
              topic: _topicSchema,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              onTap: (ContactSchema? contact) {
                ContactProfileScreen.go(context, schema: contact, clientAddress: _subscriber.clientAddress);
              },
            ),
            Divider(color: application.theme.dividerColor, height: 0, indent: 70, endIndent: 12),
          ],
        );
      },
    );
  }
}

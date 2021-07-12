import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/topic/header.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/subscriber.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/screens/contact/profile.dart';
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
  TopicSchema? _topicSchema;

  ScrollController _scrollController = ScrollController();
  bool _moreLoading = false;
  List<SubscriberSchema> _subscriberList = [];

  StreamSubscription? _updateTopicSubscription;
  StreamSubscription? _addSubscriberSubscription;
  StreamSubscription? _deleteSubscriberSubscription;
  StreamSubscription? _updateSubscriberSubscription;

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

    // exist
    topicCommon.queryByTopic(this._topicSchema?.topic).then((TopicSchema? exist) async {
      if (exist != null) return;
      TopicSchema? added = await topicCommon.add(this._topicSchema, checkDuplicated: false);
      if (added == null) return;
      setState(() {
        this._topicSchema = added;
      });
    });

    setState(() {});

    // subscribers
    _getDataSubscribers(true);
  }

  _getDataSubscribers(bool refresh) async {
    int _offset = 0;
    if (refresh) {
      _subscriberList = [];
    } else {
      _offset = _subscriberList.length;
    }
    var messages = await subscriberCommon.queryListByTopic(
      this._topicSchema?.topic,
      status: SubscriberStatus.MemberSubscribed,
      offset: _offset,
      limit: 20,
    );
    setState(() {
      _subscriberList += messages;
    });
  }

  _onTapSubscriberItem(SubscriberSchema item) async {
    ContactProfileScreen.go(context, clientAddress: item.clientAddress);
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(this.context);

    int membersCount = 0; // TODO:GG subers count(from subers table)
    bool isJoined = _topicSchema?.joined == true; // TODO:GG subers joined

    int invitedCount = 0; // TODO:GG subers
    int joinedCount = 0; // TODO:GG subers
    int rejectCount = 0; // TODO:GG subers
    String inviteContent = '$invitedCount' + _localizations.members + ':' + _localizations.invitation_sent;
    String joinedContent = '$joinedCount' + _localizations.members + ':' + _localizations.joined_channel;
    String rejectContent = '$rejectCount' + _localizations.members + ':' + _localizations.rejected;

    return Layout(
      headerColor: application.theme.backgroundColor4,
      clipAlias: false,
      header: Header(
        backgroundColor: application.theme.backgroundColor4,
        title: _localizations.channel_members,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.only(bottom: 20, left: 16, right: 16),
            child: _topicSchema != null
                ? TopicHeader(
                    topic: _topicSchema!,
                    body: Builder(
                      builder: (BuildContext context) {
                        if (_topicSchema?.isPrivate == true && _topicSchema?.isOwner(clientCommon.address) == true) {
                          return Column(
                            children: [
                              Label(
                                inviteContent,
                                type: LabelType.bodyRegular,
                                color: application.theme.successColor,
                              ),
                              Label(
                                joinedContent,
                                type: LabelType.bodyRegular,
                                color: application.theme.successColor,
                              ),
                              Label(
                                rejectContent,
                                type: LabelType.bodyRegular,
                                color: application.theme.fallColor,
                              )
                            ],
                          );
                        } else {
                          return Label(
                            '${(membersCount < 0) ? '--' : membersCount} ' + _localizations.members,
                            type: LabelType.bodyRegular,
                            color: application.theme.successColor,
                          );
                        }
                      },
                    ),
                  )
                : SizedBox.shrink(),
          ),
          Expanded(
            flex: 1,
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
        var session = _subscriberList[index];
        return Column(
          children: [
            // ChatSessionItem(
            //   session: session,
            //   onTap: (who) async {
            //     await ChatMessagesScreen.go(context, who);
            //   },
            //   onLongPress: (who) {
            //     _popItemMenu(session, index);
            //   },
            // ),
            Divider(color: application.theme.dividerColor, height: 0, indent: 70, endIndent: 12),
          ],
        );
      },
    );
  }
}

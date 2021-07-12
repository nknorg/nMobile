import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
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
  bool _pageLoaded = false;

  ScrollController _scrollController = ScrollController();
  bool _moreLoading = false;
  List<SubscriberSchema> subscribers = [];

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
        subscribers.add(schema);
      });
    });
    _deleteSubscriberSubscription = subscriberCommon.deleteStream.listen((int subscriberId) {
      setState(() {
        subscribers = subscribers.where((element) => element.id != subscriberId).toList();
      });
    });
    _updateSubscriberSubscription = subscriberCommon.updateStream.listen((SubscriberSchema event) {
      setState(() {
        subscribers = subscribers.map((e) => e.id == event.id ? event : e).toList();
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
      subscribers = [];
    } else {
      _offset = subscribers.length;
    }
    var messages = await subscriberCommon.queryListByTopic(
      this._topicSchema?.topic,
      status: SubscriberStatus.MemberSubscribed,
      offset: _offset,
      limit: 20,
    );
    setState(() {
      subscribers += messages;
    });
  }

  _onTapSubscriberItem(SubscriberSchema item) async {
    ContactProfileScreen.go(context, clientAddress: item.clientAddress);
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

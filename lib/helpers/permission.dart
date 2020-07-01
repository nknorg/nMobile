import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/chat/channel_members.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/model/data/dchat_account.dart';
import 'package:nmobile/schemas/subscribers.dart';
import 'package:nmobile/schemas/topic.dart';
import 'package:nmobile/utils/log_tag.dart';

class PermissionStatus {
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';
  static const String pending = 'pending';
}

class Permission {
  List accept;
  List reject;

  Permission({this.accept, this.reject});

  String getSubscriberStatus(String subscriber) {
    String subscriberPubkey = getPublicKeyByClientAddr(subscriber);
    if (reject != null) {
      var index = reject.indexWhere((x) {
        if (x != null) {
          if (x == '*') {
            return true;
          }
          if (x is Map<String, dynamic>) {
            if (x['addr'] != null && x['addr'] == subscriber || x['pubkey'] != null && x['pubkey'] == subscriberPubkey) {
              return true;
            }
          }
        }
        return false;
      });
      if (index > -1) {
        return PermissionStatus.rejected;
      }
    }
    if (accept != null) {
      var index = accept.indexWhere((x) {
        if (x != null) {
          if (x == '*') {
            return true;
          }
          if (x is Map<String, dynamic>) {
            if (x['addr'] != null && x['addr'] == subscriber || x['pubkey'] != null && x['pubkey'] == subscriberPubkey) {
              return true;
            }
          }
        }
        return false;
      });
      if (index > -1) {
        return PermissionStatus.accepted;
      }
    }
    return PermissionStatus.pending;
  }

  static Future<Map<String, dynamic>> getSubscribers(DChatAccount account, {String topic, meta: true, txPool: true}) async {
    try {
      String topicHash = genChannelId(topic);
      Map<String, dynamic> res =
          await getSubscribersFromDbOrNative(account, topic: topic, topicHash: topicHash, offset: 0, limit: 10000, meta: meta, txPool: txPool);
      if (isPrivateTopic(topic)) {
        res.removeWhere((key, val) {
          return key.contains('__permission__');
        });
      }
      BlocProvider.of<ChannelMembersBloc>(Global.appContext).add(MembersCount(topic, res.length, true));
      return res;
    } catch (e) {
      return getSubscribers(account, topic: topic);
    }
  }

  static Future<Map<String, dynamic>> getOwnerMeta(DChatAccount account, String accountPubkey, String topic) async {
    String topicHash = genChannelId(topic);
    String owner = getOwnerPubkeyByTopic(topic);
    int i = 0;
    Map<String, dynamic> resultMeta = Map<String, dynamic>();
    while (true) {
      var res = await account.client.getSubscription(topicHash: topicHash, subscriber: '__${i.toString()}__.__permission__.${owner}');
      if (res['meta'] == null || (res['meta'] as String).isEmpty) {
        break;
      }
      Map<String, dynamic> meta;
      try {
        meta = jsonDecode(res['meta']);
      } catch (e) {
        meta = Map<String, dynamic>();
      }
      if (meta['accept'] != null) {
        List resultMetaAccept = (resultMeta['accept'] as List);
        if (resultMetaAccept == null) {
          resultMetaAccept = [];
        }
        if (meta['accept'] is List) {
          resultMetaAccept.addAll(meta['accept']);
        }
        resultMeta['accept'] = resultMetaAccept;
      }
      if (meta['reject'] != null) {
        List resultMetaReject = (resultMeta['reject'] as List);
        if (resultMetaReject == null) {
          resultMetaReject = [];
        }
        if (meta['reject'] is List) {
          resultMetaReject.addAll(meta['reject']);
        }

        resultMeta['reject'] = resultMetaReject;
      }
      i++;
    }
    TopicSchema topicSchema = await TopicSchema.getTopic(account.dbHolder.db, topic);
    topicSchema.data = resultMeta;
    topicSchema.insertOrUpdate(account.dbHolder.db, accountPubkey);
    return resultMeta;
  }

  static Future<List<String>> getPrivateChannelDests(DChatAccount account, String topic) async {
    try {
      TopicSchema topicSchema = TopicSchema(topic: topic);
      Map<String, dynamic> meta = await topicSchema.getPrivateOwnerMeta(account);
      Map<String, dynamic> subscribers = await getSubscribers(account, topic: topic);
      Permission permission = Permission(accept: meta['accept'], reject: meta['reject']);
      List<String> acceptedSubs = List<String>();
      subscribers.forEach((key, val) {
        String status = permission.getSubscriberStatus(key);
        if (status == PermissionStatus.accepted) {
          acceptedSubs.add(key);
        }
      });
      return acceptedSubs;
    } catch (e) {
      return List<String>();
    }
  }

  static Future<Map<String, dynamic>> getSubscribersFromDbOrNative(
    DChatAccount account, {
    String topic,
    String topicHash,
    int offset = 0,
    int limit = 10000,
    bool meta = true,
    bool txPool = true,
  }) async {
    if (topic == null || topicHash == null) {
      _LOG.w('----- topic null -------');
      return {};
    }
    Map<String, dynamic> subscribers = await SubscribersSchema.getSubscribersByTopic(await account.dbHolder.db, topic);
    if (subscribers != null && subscribers.length > 0) {
      _LOG.i('getSubscribers use cache | $topic');
      _LOG.i(subscribers);

//      if (Global.isLoadSubscribers(topic)) {
//        LogUtil.v('$topic  getSubscribers use cache');
//        LogUtil.v('$subscribers ');
//        getSubscribersAction(topic: topic, topicHash: topicHash, offset: 0, limit: 10000, meta: meta, txPool: txPool).then((v) {
//          TopicSchema(topic: topic).setSubscribers(v);
//        });
//      }
      return subscribers;
    } else {
      return account.client.getSubscribers(topic: topic, topicHash: topicHash, offset: 0, limit: 10000, meta: meta, txPool: txPool);
    }
  }

  // ignore: non_constant_identifier_names
  static LOG _LOG = LOG('Permission');
}

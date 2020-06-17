import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/chat/channel_members.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/plugins/nkn_client.dart';
import 'package:nmobile/schemas/topic.dart';

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

  static Future<Map<String, dynamic>> getSubscribers({String topic, meta: true, txPool: true}) async {
    try {
      String topicHash = genChannelId(topic);
      Map<String, dynamic> res = await NknClientPlugin.getSubscribers(topic: topic, topicHash: topicHash, offset: 0, limit: 10000, meta: meta, txPool: txPool);
      if (isPrivateTopic(topic)) {
        res.removeWhere((key, val) {
          return key.contains('__permission__');
        });
      }
      BlocProvider.of<ChannelMembersBloc>(Global.appContext).add(MembersCount(topic, res.length, true));
      return res;
    } catch (e) {
      return getSubscribers();
    }
  }

  static Future<Map<String, dynamic>> getOwnerMeta(String topic) async {
    String topicHash = genChannelId(topic);
    String owner = getOwnerPubkeyByTopic(topic);
    int i = 0;
    Map<String, dynamic> resultMeta = Map<String, dynamic>();
    while (true) {
      var res = await NknClientPlugin.getSubscription(topic: topicHash, subscriber: '__${i.toString()}__.__permission__.${owner}');
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
    TopicSchema topicSchema = await TopicSchema.getTopic(topic);
    topicSchema.data = resultMeta;
    topicSchema.insertOrUpdate();
    return resultMeta;
  }

  static Future<List<String>> getPrivateChannelDests(String topic) async {
    TopicSchema topicSchema = TopicSchema(topic: topic);
    Map<String, dynamic> meta = await topicSchema.getPrivateOwnerMeta();
    Map<String, dynamic> subscribers = await getSubscribers(topic: topic);
    Permission permission = Permission(accept: meta['accept'], reject: meta['reject']);
    List<String> acceptedSubs = List<String>();
    subscribers.forEach((key, val) {
      String status = permission.getSubscriberStatus(key);
      if (status == PermissionStatus.accepted) {
        acceptedSubs.add(key);
      }
    });
    return acceptedSubs;
  }
}

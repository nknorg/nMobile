import 'dart:convert';
import 'dart:io';

import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/common/client/rpc.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/helpers/validate.dart';
import 'package:nmobile/schema/option.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/util.dart';

class TopicType {
  static const publicTopic = 1;
  static const privateTopic = 2;
}

class TopicSchema {
  int? id; // (required) <-> id
  int? createAt; // <-> create_at
  int? updateAt; // <-> update_at

  String topic; // (required) <-> topic
  int type; // (required) <-> type

  bool joined = false; // <-> joined
  int? subscribeAt; // <-> subscribe_at
  int? expireBlockHeight; // <-> expire_height

  File? avatar; // <-> avatar
  int count; // <-> count
  bool isTop = false; // <-> is_top

  OptionsSchema? options; // <-> options
  Map<String, dynamic>? data; // <-> data[...]

  TopicSchema({
    this.id,
    required this.topic,
    this.type = -1,
    this.createAt,
    this.updateAt,
    this.joined = false,
    this.subscribeAt,
    this.expireBlockHeight,
    this.avatar,
    this.count = 0,
    this.isTop = false,
    this.options,
    this.data,
  }) {
    if (type == -1) type = (Validate.isPrivateTopicOk(topic) ? TopicType.privateTopic : TopicType.publicTopic);
    if (options == null) options = OptionsSchema();
    if (data == null) data = Map();
  }

  static TopicSchema? create(String? topic, {int? type, int expireHeight = 0}) {
    if (topic == null || topic.isEmpty) return null;
    return TopicSchema(
      topic: topic,
      type: type ?? (Validate.isPrivateTopicOk(topic) ? TopicType.privateTopic : TopicType.publicTopic),
      createAt: DateTime.now().millisecondsSinceEpoch,
      updateAt: DateTime.now().millisecondsSinceEpoch,
      joined: expireHeight > 0 ? true : false,
      subscribeAt: expireHeight > 0 ? DateTime.now().millisecondsSinceEpoch : null,
      expireBlockHeight: expireHeight > 0 ? expireHeight : null,
    );
  }

  bool get isPrivate {
    if (type == -1) type = (Validate.isPrivateTopicOk(topic) ? TopicType.privateTopic : TopicType.publicTopic);
    return type == TopicType.privateTopic;
  }

  String? get ownerPubKey {
    String? owner;
    if (isPrivate) {
      int index = topic.lastIndexOf('.');
      owner = topic.substring(index + 1);
      if (owner.isEmpty) owner = null;
    } else {
      owner = null;
    }
    return owner;
  }

  String get topicName {
    String topicName;
    if (isPrivate) {
      int index = topic.lastIndexOf('.');
      if (index > 0) {
        topicName = topic.substring(0, index);
      } else {
        topicName = topic;
      }
    } else {
      topicName = topic;
    }
    return topicName;
  }

  String get topicNameShort {
    String topicNameShort;
    if (isPrivate) {
      int index = topic.lastIndexOf('.');
      if (index > 0) {
        String topicName = topic.substring(0, index);
        if (ownerPubKey?.isNotEmpty == true) {
          if ((ownerPubKey?.length ?? 0) > 8) {
            topicNameShort = topicName + '.' + (ownerPubKey?.substring(0, 8) ?? "");
          } else {
            topicNameShort = topicName + '.' + (ownerPubKey ?? "");
          }
        } else {
          topicNameShort = topicName;
        }
      } else {
        topicNameShort = topic;
      }
    } else {
      topicNameShort = topic;
    }
    return topicNameShort;
  }

  String? get displayAvatarPath {
    String? avatarLocalPath = avatar?.path;
    if (avatarLocalPath == null || avatarLocalPath.isEmpty) {
      return null;
    }
    String? completePath = Path.convert2Complete(avatarLocalPath);
    if (completePath == null || completePath.isEmpty) {
      return null;
    }
    return completePath;
  }

  Future<File?> get displayAvatarFile async {
    String? completePath = displayAvatarPath;
    if (completePath == null || completePath.isEmpty) {
      return Future.value(null);
    }

    File avatarFile = File(completePath);
    bool exits = await avatarFile.exists();
    if (!exits) {
      return Future.value(null);
    }
    return avatarFile;
  }

  bool isOwner(String? contactAddress) {
    if (!isPrivate || contactAddress == null || contactAddress.isEmpty) return false;
    String? pubKey = getPubKeyFromTopicOrChatId(contactAddress);
    return (pubKey?.isNotEmpty == true) && (pubKey == ownerPubKey);
  }

  Future<bool> shouldResubscribe(int? globalHeight) async {
    if ((expireBlockHeight == null) || ((expireBlockHeight ?? 0) <= 0)) return true;
    globalHeight = globalHeight ?? (await RPC.getBlockHeight());
    if (globalHeight != null && globalHeight > 0) {
      return ((expireBlockHeight ?? 0) - globalHeight) < Settings.blockHeightTopicWarnBlockExpire;
    }
    return true;
  }

  bool isSubscribeProgress() {
    bool? isProgress = data?['subscribe_progress'];
    if (isProgress == null) return false;
    return isProgress;
  }

  bool isUnSubscribeProgress() {
    bool? isProgress = data?['unsubscribe_progress'];
    if (isProgress == null) return false;
    return isProgress;
  }

  int? getProgressSubscribeNonce() {
    int? nonce = int.tryParse(data?['progress_subscribe_nonce']?.toString() ?? "");
    if (nonce == null || nonce < 0) return null;
    return nonce;
  }

  double getProgressSubscribeFee() {
    double? fee = double.tryParse(data?['progress_subscribe_fee']?.toString() ?? "");
    if (fee == null || fee < 0) return 0;
    return fee;
  }

  int lastCheckSubscribeAt() {
    return int.tryParse(data?['last_check_subscribe_at']?.toString() ?? "0") ?? 0;
  }

  int lastCheckPermissionsAt() {
    return int.tryParse(data?['last_check_permissions_at']?.toString() ?? "0") ?? 0;
  }

  int lastRefreshSubscribersAt() {
    return int.tryParse(data?['last_refresh_subscribers_at']?.toString() ?? "0") ?? 0;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'id': id,
      'create_at': createAt ?? DateTime.now().millisecondsSinceEpoch,
      'update_at': updateAt ?? DateTime.now().millisecondsSinceEpoch,
      'topic': topic,
      'type': type,
      'joined': joined ? 1 : 0,
      'subscribe_at': subscribeAt,
      'expire_height': expireBlockHeight,
      'avatar': Path.convert2Local(avatar?.path),
      'count': count,
      'is_top': isTop ? 1 : 0,
      'options': options != null ? jsonEncode(options) : OptionsSchema(),
      'data': data != null ? jsonEncode(data) : Map(),
    };
    return map;
  }

  static TopicSchema fromMap(Map<String, dynamic> e) {
    var topicSchema = TopicSchema(
      id: e['id'],
      createAt: e['create_at'],
      updateAt: e['update_at'],
      topic: e['topic'] ?? "",
      type: e['type'] ?? -1,
      joined: (e['joined'] != null) && (e['joined'] == 1) ? true : false,
      subscribeAt: e['subscribe_at'],
      expireBlockHeight: e['expire_height'],
      avatar: Path.convert2Complete(e['avatar']) != null ? File(Path.convert2Complete(e['avatar'])!) : null,
      count: e['count'] ?? 0,
      isTop: (e['is_top'] != null) && (e['is_top'] == 1) ? true : false,
      data: (e['data']?.toString().isNotEmpty == true) ? Util.jsonFormatMap(e['data']) : null,
    );
    // options
    if (e['options']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? options = Util.jsonFormatMap(e['options']);
      topicSchema.options = OptionsSchema.fromMap(options ?? Map());
    }
    // data
    if (e['data']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? data = Util.jsonFormatMap(e['data']);
      if (data != null) topicSchema.data?.addAll(data);
    }
    return topicSchema;
  }

  @override
  String toString() {
    return 'TopicSchema{id: $id, createAt: $createAt, updateAt: $updateAt, topic: $topic, type: $type, joined: $joined, subscribeAt: $subscribeAt, expireBlockHeight: $expireBlockHeight, avatar: $avatar, count: $count, isTop: $isTop, options: $options, data: $data}';
  }
}

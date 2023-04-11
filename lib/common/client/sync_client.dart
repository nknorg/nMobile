import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/client.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/error.dart';
import '../../schema/message.dart';
import '../../schema/wallet.dart';
import '../../storages/sync_message.dart';
import '../../utils/logger.dart';
import '../../utils/util.dart';
import '../locator.dart';
import '../settings.dart';
import 'client.dart';

class SyncClient with Tag {
  Client? client;

  String? get address => client?.address;
  String? instanceId;
  String? version;
  StreamSubscription? _onErrorStreamSubscription;
  StreamSubscription? _onConnectStreamSubscription;
  StreamSubscription? _onMessageStreamSubscription;

  late SyncMessageStorage _syncMessageStorage;

  String? getPublicKey() {
    Uint8List? pkOriginal = client?.publicKey;
    if ((pkOriginal == null) || pkOriginal.isEmpty) return null;
    try {
      String pk = hexEncode(pkOriginal);
      return pk.isEmpty ? null : pk;
    } catch (e, st) {
      handleError(e, st);
    }
    return null;
  }

  Future<bool> connect(WalletSchema wallet, String password, List<String> seedRPCServerAddr) async {
    _syncMessageStorage = SyncMessageStorage(key: wallet.publicKey);
    instanceId = await _syncMessageStorage.getInstanceId();
    if (instanceId?.isNotEmpty != true) {
      instanceId = Uuid().v4();
      await _syncMessageStorage.setInstanceId(instanceId!);
    }
    logger.d('InstanceId: $instanceId');
    await _syncMessageStorage.put(instanceId!, Settings.deviceName);
    String seed = await walletCommon.getSeed(wallet.address);
    try {
      if (client == null) {
        ClientConfig config = ClientConfig(seedRPCServerAddr: seedRPCServerAddr);
        while ((client?.address == null) || (client?.address.isEmpty == true)) {
          client = await Client.create(hexDecode(seed), identifier: '__${instanceId}__', numSubClients: 4, config: config);
        }
        _startListen(wallet);
      } else {
        // reconnect will break in go-sdk, because connect closed when fail and no callback
        // maybe no go here, because closed too long, reconnect too long more
        await client?.reconnect(); // no onConnect callback
        await Future.delayed(Duration(milliseconds: 1000)); // reconnect need more time
      }
    } catch (e, st) {
      handleError(e, st, toast: false);
      return false;
    }
    return true;
  }

  void _startListen(WalletSchema wallet) {
    // client error
    _onErrorStreamSubscription = client?.onError.listen((dynamic event) async {
      logger.e("$TAG - onError -> event:${event.toString()}");
      handleError(event, null, text: "client error");
    });
    // client connect (just listen once)
    _onConnectStreamSubscription = client?.onConnect.listen((OnConnect event) async {
      logger.i("$TAG - onConnect -> node:${event.node} - rpcServers:${event.rpcServers}");
      // send message to self
      sendPing();
    });
    // client receive (looper)
    _onMessageStreamSubscription = client?.onMessage.listen((OnMessage event) async{
      Map<String, dynamic>? data = Util.jsonFormatMap(event.data);
      if (data == null) {
        return;
      }
      var content = data['data'];
      if (data['contentType'] == MessageContentType.syncMessage && content['from'] == clientCommon.address) {
        event.src = content['from'];
        event.data = jsonEncode(content);
        var message = MessageSchema.fromReceive(content['to'], event);
        message?.isOutbound = true;
        message?.status = MessageStatus.Success;
        content.remove('from');
        content.remove('to');
        message?.contentType = content['contentType'];
        await chatOutCommon.insertMessage(message);
        await chatCommon.sessionHandle(message!);
      } else {
        onMessageReceive(event);
        chatInCommon.onMessageReceive(MessageSchema.fromReceive(clientCommon.address ?? "", event));
      }
    });
  }

  Future _stopListen() async {
    await _onErrorStreamSubscription?.cancel();
    await _onConnectStreamSubscription?.cancel();
    await _onMessageStreamSubscription?.cancel();
  }

  onSyncMessage(OnMessage message, String to) async {
    Map<String, dynamic>? data = Util.jsonFormatMap(message.data);
    if (data == null) {
      return;
    }
    switch (data['contentType']) {
      case MessageContentType.receipt:
      case MessageContentType.read:
      case MessageContentType.contactProfile:
      case MessageContentType.contactOptions:
      case MessageContentType.deviceRequest:
      case MessageContentType.deviceInfo:
      case MessageContentType.text:
      case MessageContentType.textExtension:
      case MessageContentType.ipfs:
      case MessageContentType.media:
      case MessageContentType.image:
      case MessageContentType.audio:
      case MessageContentType.piece:
      case MessageContentType.topicInvitation:
      case MessageContentType.topicSubscribe:
      case MessageContentType.topicUnsubscribe:
      case MessageContentType.topicKickOut:
      case MessageContentType.privateGroupInvitation:
      case MessageContentType.privateGroupAccept:
      case MessageContentType.privateGroupSubscribe:
      case MessageContentType.privateGroupQuit:
      case MessageContentType.privateGroupOptionRequest:
      case MessageContentType.privateGroupOptionResponse:
      case MessageContentType.privateGroupMemberRequest:
      case MessageContentType.privateGroupMemberResponse:
        syncAllDevicesMessage(message.src!, to, data);
        break;
    }
  }

  Future onMessageReceive(OnMessage message) async {
    String? sPubkey = getPubKeyFromTopicOrChatId(message.src!);
    String? publicKey = getPublicKey();
    if (sPubkey != publicKey) {
      return;
    }
    Map<String, dynamic>? data = Util.jsonFormatMap(message.data);
    if (data == null) {
      return;
    }

    String? instanceId = data['instanceId'];
    if (instanceId == null || instanceId == this.instanceId) {
      return;
    }

    switch (data['contentType']) {
      case MessageContentType.syncPing:
        this.sendRequestInstance(instanceId);
        break;
      case MessageContentType.syncRequestInstance:
        this.sendResponseInstance(instanceId);
        List list = data['data'];
        list.forEach((e) async {
          await _syncMessageStorage.put(e['id'], e['name']);
        });
        await _syncMessageStorage.setVersion();
        break;
      case MessageContentType.syncResponseInstance:
        List list = data['data'];
        list.forEach((e) async {
          await _syncMessageStorage.put(e['id'], e['name']);
        });
        await _syncMessageStorage.setVersion();
        break;
      case MessageContentType.syncMessage:
        var content = data['data'];
        message.src = content['from'];
        content.remove('from');
        content.remove('to');
        message.data = jsonEncode(content);
        break;
    }
  }

  createSyncMessageData(String from, String to, Map<String, dynamic> data) {
    data['from'] = from;
    data['to'] = to;
    return data;
  }

  Future<Map> createMessageData(String contentType, {String? id, int? timestamp}) async {
    String version = await _syncMessageStorage.getVersion();
    Map map = {
      'id': id ?? Uuid().v4(),
      'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
      'instanceId': instanceId,
      'version': version,
      'contentType': contentType,
    };
    return map;
  }

  Future sendPing() async {
    var data = await createMessageData(MessageContentType.syncPing);
    String publicKey = getPublicKey()!;
    await clientCommon.client?.sendText([publicKey], jsonEncode(data));
  }

  Future sendRequestInstance(String identifier) async {
    var data = await createMessageData(MessageContentType.syncRequestInstance);
    String publicKey = getPublicKey()!;
    data['data'] = await _syncMessageStorage.getDevicesArray();
    await clientCommon.client?.sendText(['__${identifier}__.$publicKey'], jsonEncode(data));
  }

  Future sendResponseInstance(String identifier) async {
    var data = await createMessageData(MessageContentType.syncResponseInstance);
    String publicKey = getPublicKey()!;
    data['data'] = await _syncMessageStorage.getDevicesArray();
    await clientCommon.client?.sendText(['__${identifier}__.$publicKey'], jsonEncode(data));
  }

  Future sendSyncMessage(String identifier, String from, String to, data) async {
    var body = await createMessageData(MessageContentType.syncMessage);
    body['data'] = createSyncMessageData(from, to, data);
    String publicKey = getPublicKey()!;
    await clientCommon.client?.sendText(['__${identifier}__.$publicKey'], jsonEncode(body));
  }

  Future syncAllDevicesMessage(String from, String to, data) async {
    logger.d('need to sync message');
    List devices = await _syncMessageStorage.getDevicesArray();
    logger.d('Devices: $devices');
    for (var item in devices) {
      var instanceId = item['id'];
      if (instanceId == this.instanceId) {
        continue;
      }
      this.sendSyncMessage(instanceId, from, to, data);
    }
  }
}

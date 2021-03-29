import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/blocs/chat/chat_state.dart';
import 'package:nmobile/blocs/contact/contact_bloc.dart';
import 'package:nmobile/blocs/contact/contact_event.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/model/datacenter/contact_data_center.dart';
import 'package:nmobile/model/datacenter/group_data_center.dart';
import 'package:nmobile/model/datacenter/message_data_center.dart';
import 'package:nmobile/model/db/nkn_data_manager.dart';
import 'package:nmobile/model/entity/subscriber_repo.dart';
import 'package:nmobile/model/entity/topic_repo.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/model/entity/contact.dart';
import 'package:nmobile/model/group_chat_helper.dart';
import 'package:nmobile/model/entity/message.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:path/path.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> with Tag {
  @override
  ChatState get initialState => NoConnectState();
  final ContactBloc contactBloc;

  ChatBloc({@required this.contactBloc});

  /// This variable used to Check If the AndroidDevice got FCM Ability
  /// If so,there is no need to alert Notification while in ForegroundState by Android Device
  bool googleServiceOn = false;
  bool googleServiceOnInit = false;

  List<MessageSchema> entityMessageList = new List();
  List<MessageSchema> actionMessageList = new List();
  Timer watchDog;
  int delayResendSeconds = 15;

  Map judgeToResendMessage = new Map();

  Uint8List messageIn, messageOut;

  int perPieceLength = (1024 * 8);
  int maxPieceCount = 25;

  bool groupUseOnePiece = true;

  @override
  Stream<ChatState> mapEventToState(ChatEvent event) async* {
    if (event is NKNChatOnMessageEvent) {
      yield OnConnectState();
    } else if (event is ReceiveMessageEvent) {
      yield* _mapReceiveMessageToState(event);
    } else if (event is SendMessageEvent) {
      yield* _mapSendMessageToState(event);
    } else if (event is RefreshMessageListEvent) {
      var unReadCount = await MessageSchema.unReadMessages();
      FlutterAppBadger.updateBadgeCount(unReadCount);
      yield MessageUpdateState(target: event.target);
    } else if (event is RefreshMessageChatEvent) {
      yield MessageUpdateState(
          target: event.message.to, message: event.message);
    } else if (event is UpdateChatEvent) {
      String targetId = event.targetId;

      var res =
          await MessageSchema.getAndReadTargetMessages(targetId, limit: 20);
      this.add(RefreshMessageListEvent(target: targetId));
      yield UpdateChatMessageState(res);
    } else if (event is GetAndReadMessages) {
      yield* _mapGetAndReadMessagesToState(event);
    }
  }

  _resendMessage(MessageSchema message) async {
    var cdb = await NKNDataManager().currentDatabase();

    var res = await cdb.query(
      MessageSchema.tableName,
      columns: ['*'],
      orderBy: 'send_time desc',
      where: '(type = ? or type = ?) AND sender = ? AND receiver = ? '
          'AND is_success = 0',
      whereArgs: [
        ContentType.text,
        ContentType.textExtension,
        message.to,
        message.from
      ],
      limit: 20,
      offset: 0,
    );

    List<MessageSchema> messages = <MessageSchema>[];
    for (var i = 0; i < res.length; i++) {
      var messageItem = MessageSchema.parseEntity(res[i]);
      messages.add(messageItem);
    }
    if (res.isNotEmpty) {
      NLog.w('ResendMessage___' + res.length.toString());
      for (MessageSchema message in messages) {
        if (message.isSuccess == false && message.isSendMessage()) {
          this.add(SendMessageEvent(message));
        }
      }
    }
  }

  _judgeResend() async {
    /// Query UnreadMessage and resend it to the very ClientAddress
    if (delayResendSeconds == 0) {
      for (String key in judgeToResendMessage.keys) {
        MessageSchema message = judgeToResendMessage[key];
        _resendMessage(message);
      }

      _stopWatchDog();
    }
    delayResendSeconds--;
  }

  _startWatchDog(MessageSchema msg) {
    if (watchDog == null || watchDog.isActive == false) {
      /// because it is Receipt message, so keep msg.from
      if (!judgeToResendMessage.containsKey(msg.from)) {
        judgeToResendMessage[msg.from] = msg;
      }

      delayResendSeconds = 15;
      watchDog = Timer.periodic(Duration(milliseconds: 1000), (timer) async {
        _judgeResend();
      });
    }
  }

  _stopWatchDog() {
    delayResendSeconds = 15;
    if (watchDog.isActive) {
      watchDog.cancel();
      watchDog = null;
    }
  }

  _watchSendMessage(MessageSchema message) async {
    bool pidExists = await MessageDataCenter.judgeMessagePid(message.msgId);
    if (pidExists == false) {
      message.setMessageStatus(MessageStatus.MessageSendFail);
    }
  }

  Stream<ChatState> _mapSendMessageToState(SendMessageEvent event) async* {
    var message = event.message;
    String contentData = '';
    await message.insertSendMessage();

    /// Handle GroupMessage Sending
    if (message.topic != null) {
      try {
        message.setMessageStatus(MessageStatus.MessageSending);
        _sendGroupMessage(message);
      } catch (e) {
        NLog.w('SendMessage Failed E:_____'+e.toString());
        message.setMessageStatus(MessageStatus.MessageSendFail);
      }

      yield MessageUpdateState(target: message.to, message: message);
      return;
    }

    /// Handle SingleMessage Sending
    else {
      if (message.contentType == ContentType.text ||
          message.contentType == ContentType.textExtension ||
          message.contentType == ContentType.nknAudio ||
          message.contentType == ContentType.media ||
          message.contentType == ContentType.nknImage ||
          message.contentType == ContentType.channelInvitation) {
        if (message.options != null &&
            message.options['deleteAfterSeconds'] != null) {
          message.deleteTime = DateTime.now()
              .add(Duration(seconds: message.options['deleteAfterSeconds']));
          await message.updateDeleteTime();
        }
        _checkIfSendNotification(message.to, '');

        if (message.contentType == ContentType.text ||
            message.contentType == ContentType.textExtension ||
            message.contentType == ContentType.channelInvitation) {
          contentData = message.toTextData();
        }
        else{
          bool useOnePiece = false;
          String key = LocalStorage.NKN_ONE_PIECE_READY_JUDGE + message.to;
          String onePieceReady = await LocalStorage().get(key);
          NLog.w('onePieceReady is____' + onePieceReady.toString());
          if (onePieceReady != null && onePieceReady.length > 0) {
            useOnePiece = true;
            NLog.w('useOnePiece Send!!!!!!');
          }
          if (useOnePiece &&
              (message.contentType == ContentType.nknAudio ||
                  message.contentType == ContentType.media ||
                  message.contentType == ContentType.nknImage)) {
            _sendOnePieceMessage(message);
            return;
          } else {
            if (message.contentType == ContentType.media ||
                message.contentType == ContentType.nknImage){
              /// Warning todo remove this When most user's version is above 1.1.0
              String extraSendForAndroidSuit = message.toSuitVersionImageData(ContentType.nknImage);
              try {
                Uint8List pid = await NKNClientCaller.sendText(
                    [message.to], extraSendForAndroidSuit, message.msgId);
                if(pid != null){
                  message.setMessageStatus(MessageStatus.MessageSendSuccess);
                  MessageDataCenter.updateMessagePid(pid, message.msgId);
                }
                NLog.w('extraSendForAndroidSuit___'+pid.toString());
              } catch (e) {
                NLog.w('Wrong___' + e.toString());
                message.setMessageStatus(MessageStatus.MessageSendFail);
              }
              /// Warning todo remove this When most user's version is above 1.1.0
              String extraSendForiOSSuit = message.toSuitVersionImageData('image');
              try {
                Uint8List pid = await NKNClientCaller.sendText(
                    [message.to], extraSendForiOSSuit, message.msgId);
                if(pid != null){
                  message.setMessageStatus(MessageStatus.MessageSendSuccess);
                  MessageDataCenter.updateMessagePid(pid, message.msgId);
                }
                NLog.w('extraSendForiOSSuit___'+pid.toString());
              } catch (e) {
                NLog.w('Wrong___' + e.toString());
                message.setMessageStatus(MessageStatus.MessageSendFail);
              }
            }
          }
        }
      } else if (message.contentType == ContentType.nknOnePiece) {
        contentData = message.toNknPieceMessageData();
      } else if (message.contentType == ContentType.eventContactOptions) {
        contentData = message.content;
      }

      NLog.w('ContentData is_____'+contentData.toString());

      try {
        Uint8List pid = await NKNClientCaller.sendText(
            [message.to], contentData, message.msgId);
        if(pid != null){
          message.setMessageStatus(MessageStatus.MessageSendSuccess);
          MessageDataCenter.updateMessagePid(pid, message.msgId);
          NLog.w('Pid is_____'+pid.toString());
        }
      } catch (e) {
        NLog.w('Wrong___' + e.toString());
        message.setMessageStatus(MessageStatus.MessageSendFail);
      }
    }

    this.add(RefreshMessageListEvent());
    yield MessageUpdateState(target: message.to, message: message);
  }

  _combineOnePieceMessage(MessageSchema onePieceMessage) async {
    bool exist = await onePieceMessage.existOnePieceIndex();
    if (exist) {
      return;
    }

    Uint8List bytes = base64Decode(onePieceMessage.content);

    if (bytes.length > perPieceLength) {
      perPieceLength = bytes.length;
    }
    String name = hexEncode(md5.convert(bytes).bytes);

    String path = getCachePath(NKNClientCaller.currentChatId);
    name = onePieceMessage.msgId + '-nkn-' + name;

    String filePath =
        join(path, name + '.' + onePieceMessage.parentType.toString());
    NLog.w('FileLength is____' + bytes.length.toString());
    File file = File(filePath);

    file.writeAsBytesSync(bytes, flush: true);

    onePieceMessage.content = file;
    onePieceMessage.options = {
      'parity': onePieceMessage.parity,
      'total': onePieceMessage.total,
      'index': onePieceMessage.index,
      'parentType': onePieceMessage.parentType,
      'deleteAfterSeconds': onePieceMessage.deleteAfterSeconds,
      'audioDuration': onePieceMessage.audioFileDuration,
    };
    await onePieceMessage.insertOnePieceMessage();

    int total = onePieceMessage.total;

    List allPieces = await onePieceMessage.allPieces();

    bool existFull = await onePieceMessage.existFullPiece();
    if (existFull) {
      NLog.w(
          '_combineOnePieceMessage existOnePiece___' + onePieceMessage.msgId);
      return;
    }

    if (allPieces.length == total) {
      NLog.w('onePieceMessage total is___\n' +
          onePieceMessage.total.toString() +
          'parity is__' +
          onePieceMessage.parity.toString());
      NLog.w('onePieceMessage bytesLength is___' +
          onePieceMessage.bytesLength.toString());

      File eFile = onePieceMessage.content as File;
      int pLength = eFile.readAsBytesSync().length;
      int shardTotal = onePieceMessage.total + onePieceMessage.parity;

      shardTotal = onePieceMessage.total + onePieceMessage.parity;

      // shardTotal = 13;

      List recoverList = new List();
      for (int i = 0; i < shardTotal; i++) {
        MessageSchema onePiece;
        for (MessageSchema schema in allPieces) {
          if (schema.index == i) {
            onePiece = schema;
          }
        }
        if (onePiece != null) {
          File oneFile = onePiece.content as File;
          Uint8List fBytes = oneFile.readAsBytesSync();
          recoverList.add(fBytes);
          NLog.w('Fill fBytes ___' +
              fBytes
                  .getRange(fBytes.length ~/ 2, fBytes.length - 1)
                  .toString());
        } else {
          recoverList.add(Uint8List(0));
          NLog.w('Fill EmptyList ___' + i.toString());
        }
      }

      if (recoverList.length < onePieceMessage.total) {
        NLog.w('Wrong!!!! recoverList is too short!');
        return;
      }

      String recoverString = await NKNClientCaller.combinePieces(
          recoverList,
          onePieceMessage.total,
          onePieceMessage.parity,
          onePieceMessage.bytesLength);

      NLog.w('recoverString length is___' + recoverString.length.toString());
      Uint8List fBytes;
      try {
        fBytes = base64Decode(recoverString);
      } catch (e) {
        NLog.w('Base64Decode Error:' + e.toString());
      }

      NLog.w('Step4__  fBytes   ' + fBytes.length.toString());
      String name = hexEncode(md5.convert(fBytes).bytes);
      name = onePieceMessage.msgId + '-nkn-' + name;

      String extension = 'media';
      if (onePieceMessage.parentType == ContentType.nknAudio) {
        extension = 'aac';
      }

      String fullPath = getCachePath(NKNClientCaller.currentChatId);
      File fullFile = File(join(fullPath, name + '$extension'));
      fullFile.writeAsBytes(fBytes, flush: true);

      Duration deleteAfterSeconds;
      if (onePieceMessage.deleteAfterSeconds != null) {
        deleteAfterSeconds =
            Duration(seconds: onePieceMessage.deleteAfterSeconds);
      }

      MessageSchema nReceived = MessageSchema.formReceivedMessage(
        topic: onePieceMessage.topic,
        msgId: onePieceMessage.msgId,
        from: onePieceMessage.from,
        to: onePieceMessage.to,
        pid: onePieceMessage.pid,
        contentType: onePieceMessage.parentType,
        content: fullFile,
        audioFileDuration: onePieceMessage.audioFileDuration,
      );

      nReceived.options = onePieceMessage.options;
      if (onePieceMessage.options != null &&
          onePieceMessage.options['deleteAfterSeconds'] != null) {
        nReceived.deleteTime = DateTime.now().add(
            Duration(seconds: onePieceMessage.options['deleteAfterSeconds']));
      }

      await nReceived.insertReceivedMessage();

      nReceived.setMessageStatus(MessageStatus.MessageReceived);
      nReceived.sendReceiptMessage();

      MessageDataCenter.removeOnePieceCombinedMessage(nReceived.msgId);

      this.add(RefreshMessageListEvent());
      this.add(RefreshMessageChatEvent(nReceived));
    }
  }

  _sendOnePiece(List mpList, MessageSchema parentMessage) async {
    for (int index = 0; index < mpList.length; index++) {
      // String content = mpList[index];
      NLog.w('FileType is___'+mpList[index].runtimeType.toString());
      Uint8List fileP = mpList[index];
      NLog.w('fileP is___'+fileP.length.toString());

      Duration deleteAfterSeconds;
      if (parentMessage.topic == null){
        ContactSchema contact = await _checkContactIfExists(parentMessage.to);
        if (contact?.options != null) {
          if (contact?.options?.deleteAfterSeconds != null) {
            deleteAfterSeconds =
                Duration(seconds: contact.options.deleteAfterSeconds);
          }
        }
      }
      String content = base64Encode(fileP);

      NLog.w('Send OnePiece with Content__' +
          index.toString() +
          '__' +
          parentMessage.bytesLength.toString());

      Duration duration = Duration(milliseconds: index * 100);
      Timer(duration, () async {
        var nknOnePieceMessage = MessageSchema.fromSendData(
          topic: parentMessage.topic,
          msgId: parentMessage.msgId,
          from: parentMessage.from,
          to: parentMessage.to,
          parentType: parentMessage.contentType,
          content: content,
          contentType: ContentType.nknOnePiece,
          parity: parentMessage.parity,
          total: parentMessage.total,
          index: index,
          bytesLength: parentMessage.bytesLength,
          deleteAfterSeconds: deleteAfterSeconds,
          audioFileDuration: parentMessage.audioFileDuration,
        );
        if (parentMessage.topic != null){
          nknOnePieceMessage = MessageSchema.fromSendData(
            topic: parentMessage.topic,
            msgId: parentMessage.msgId,
            from: parentMessage.from,
            parentType: parentMessage.contentType,
            content: content,
            contentType: ContentType.nknOnePiece,
            parity: parentMessage.parity,
            total: parentMessage.total,
            index: index,
            bytesLength: parentMessage.bytesLength,
            deleteAfterSeconds: deleteAfterSeconds,
            audioFileDuration: parentMessage.audioFileDuration,
          );
        }
        NLog.w('Send OnePiece with index__' +
            index.toString() +
            '__' +
            parentMessage.bytesLength.toString());
        this.add(SendMessageEvent(nknOnePieceMessage));
      });
    }
  }

  _sendOnePieceMessage(MessageSchema message) async {
    File file = message.content as File;

    Uint8List fileBytes = file.readAsBytesSync();
    String base64Content = base64.encode(fileBytes);

    int total = 10;
    int parity = total ~/ 3;
    if (base64Content.length <= perPieceLength) {
      total = 1;
      parity = 1;
    } else if (base64Content.length > perPieceLength &&
        base64Content.length < 25 * perPieceLength) {
      total = base64Content.length ~/ perPieceLength;
      if (base64Content.length % perPieceLength > 0) {
        total += 1;
      }
      parity = total ~/ 3;
    } else {
      total = maxPieceCount;
      parity = total ~/ 3;
    }
    if (parity == 0) {
      parity = 1;
    }

    message.total = total;
    message.parity = parity;
    message.bytesLength = base64Content.length;

    NLog.w('fileBytes.length is__' + fileBytes.length.toString());
    NLog.w('base64Content Length is____' + base64Content.length.toString());
    NLog.w('SendOnePieceTopic is______'+message.topic.toString());

    var dataList =
        await NKNClientCaller.intoPieces(base64Content, total, parity);
    NLog.w('_sendOnePieceMessage__Length__' + dataList.length.toString());
    _sendOnePiece(dataList, message);

    return;
  }

  _sendGroupMessage(MessageSchema message) async {
    if (message.contentType == ContentType.text ||
        message.contentType == ContentType.textExtension ||
        message.contentType == ContentType.nknAudio ||
        message.contentType == ContentType.media ||
        message.contentType == ContentType.nknImage ||
        message.contentType == ContentType.channelInvitation) {
      if (message.options != null &&
          message.options['deleteAfterSeconds'] != null) {
        message.deleteTime = DateTime.now()
            .add(Duration(seconds: message.options['deleteAfterSeconds']));
        await message.updateDeleteTime();
      }

      List<Subscriber> groupMembers =
      await GroupDataCenter.fetchSubscribedMember(message.topic);
      for (Subscriber sub in groupMembers){
        _checkIfSendNotification(sub.chatId, '');
      }
    }

    String encodeSendJsonData;
    if (message.contentType == ContentType.text) {
      encodeSendJsonData = message.toTextData();
    } else if (message.contentType == ContentType.nknImage ||
        message.contentType == ContentType.media) {
      encodeSendJsonData = message.toSuitVersionImageData(ContentType.media);
    } else if (message.contentType == ContentType.nknAudio) {
      encodeSendJsonData = message.toAudioData();
    } else if (message.contentType == ContentType.eventSubscribe) {
      encodeSendJsonData = message.toEventSubscribeData();
    } else if (message.contentType == ContentType.eventUnsubscribe) {
      encodeSendJsonData = message.toEventUnSubscribeData();
    }
    if (groupUseOnePiece){
      if (message.contentType == ContentType.text ||
          message.contentType == ContentType.eventSubscribe ||
          message.contentType == ContentType.eventUnsubscribe){
        _sendGroupMessageWithJsonEncode(message, encodeSendJsonData);
      }
      else if (message.contentType == ContentType.nknOnePiece){
        List<String> targets = await GroupDataCenter.fetchGroupMembersTargets(message.topic);
        String onePieceEncodeData = message.toNknPieceMessageData();
        if (targets != null && targets.length > 0) {
          Uint8List pid = await NKNClientCaller.sendText(
              targets, onePieceEncodeData, message.msgId);
          message.setMessageStatus(MessageStatus.MessageSendSuccess);
          MessageDataCenter.updateMessagePid(pid, message.msgId);
        } else {
          if (message.topic != null) {
            NLog.w('Wrong !!!Topic got no Member' + message.topic);
          }
        }
      }
      else{
        NLog.w('groupUseOnePiece___'+message.contentType.toString());
        _sendOnePieceMessage(message);
        /// Warning todo remove this When most user's version is above 1.1.0
        _sendGroupMessageWithJsonEncode(message, encodeSendJsonData);
      }
    }
    else{
      _sendGroupMessageWithJsonEncode(message, encodeSendJsonData);
    }
  }

  _sendGroupMessageWithJsonEncode(MessageSchema message,String encodeJson) async{
    if (isPrivateTopicReg(message.topic)){
      List<String> targets = await GroupDataCenter.fetchGroupMembersTargets(message.topic);
      if (targets != null && targets.length > 0) {
        Uint8List pid = await NKNClientCaller.sendText(
            targets, encodeJson, message.msgId);
        message.setMessageStatus(MessageStatus.MessageSendSuccess);
        MessageDataCenter.updateMessagePid(pid, message.msgId);
      } else {
        if (message.topic != null) {
          NLog.w('Wrong !!!Topic got no Member' + message.topic);
        }
      }
    } else {
      Uint8List pid;
      try {
        pid = await NKNClientCaller.publishText(
            genTopicHash(message.topic), encodeJson);
        message.setMessageStatus(MessageStatus.MessageSendSuccess);
      } catch (e) {
        message.setMessageStatus(MessageStatus.MessageSendFail);
        NLog.w('_sendGroupMessageWithJsonEncode E:'+e.toString());
      }
      NLog.w('_sendGroupMessageWithJsonEncode WithContent:'+jsonDecode(encodeJson).toString());
      NLog.w('_sendGroupMessageWithJsonEncode With pid:'+pid.toString());
      if (pid != null) {
        MessageDataCenter.updateMessagePid(pid, message.msgId);
      }
    }
  }

  _insertMessage(MessageSchema message) async {
    bool insertReceiveSuccess = await message.insertReceivedMessage();
    if (insertReceiveSuccess) {
      message.setMessageStatus(MessageStatus.MessageReceived);
      message.sendReceiptMessage();

      var unReadCount = await MessageSchema.unReadMessages();
      FlutterAppBadger.updateBadgeCount(unReadCount);
    } else {
      NLog.w('Insert Message failed' + message.contentType.toString());
    }
  }

  Stream<ChatState> _mapReceiveMessageToState(
      ReceiveMessageEvent event) async* {
    var message = event.message;

    /// judge if ReceivedMessage duplicated
    bool messageExist = await message.isReceivedMessageExist();
    if (messageExist == true) {
      /// should retry here!!!
      if (message.isSuccess == false &&
          message.contentType != ContentType.nknOnePiece) {
        message.sendReceiptMessage();
      }
      NLog.w('ReceiveMessage from AnotherNode__');
      return;
    }
    else{
      /// judge ReceiveMessage if D-Chat PC groupMessage Receipt
      MessageSchema dChatPcReceipt = await MessageSchema.findMessageWithMessageId(event.message.msgId);
      if (dChatPcReceipt != null && dChatPcReceipt.contentType != ContentType.nknOnePiece){
        dChatPcReceipt = await dChatPcReceipt.receiptMessage();

        dChatPcReceipt.content = message.msgId;
        dChatPcReceipt.contentType = ContentType.receipt;
        dChatPcReceipt.topic = null;

        yield MessageUpdateState(target: dChatPcReceipt.from, message: dChatPcReceipt);
        return;
      }
    }

    if (message.contentType == ContentType.receipt) {
      MessageSchema oMessage = await message.receiptMessage();
      if (oMessage != null){

        oMessage.content = oMessage.msgId;
        oMessage.contentType = ContentType.receipt;
        oMessage.topic = null;

        yield MessageUpdateState(target: oMessage.from, message: oMessage);
        return;
      }
    }

    bool existOnePiece = await message.isOnePieceExist();
    if (existOnePiece == true) {
      return;
    }

    ContactSchema contact = await _checkContactIfExists(message.from);
    if (!contact.isMe &&
        message.contentType != ContentType.contact &&
        Global.isLoadProfile(contact.publicKey)) {
      if (contact.profileExpiresAt == null ||
          DateTime.now().isAfter(contact.profileExpiresAt)) {
        Global.saveLoadProfile(contact.publicKey);

        ContactDataCenter.requestProfile(contact, RequestType.header);
      }
    }

    if (message.contentType == ContentType.text ||
        message.contentType == ContentType.textExtension ||
        message.contentType == ContentType.nknAudio ||
        message.contentType == ContentType.nknImage ||
        message.contentType == ContentType.media ||
        message.contentType == ContentType.eventContactOptions ||
        message.contentType == ContentType.eventSubscribe ||
        message.contentType == ContentType.eventUnsubscribe ||
        message.contentType == ContentType.channelInvitation) {
      /// If Received self Send
      if (message.from == NKNClientCaller.currentChatId) {
        MessageSchema oMessage = await message.receiptMessage();
        yield MessageUpdateState(target: oMessage.from, message: oMessage);
        return;
      } else {
        NLog.w('_insertMessage');
        if (message.contentType == ContentType.eventSubscribe ||
            message.contentType == ContentType.eventUnsubscribe) {
          if (message.from == NKNClientCaller.currentChatId) {} else {
            if (message.topic != null) {
              if (isPrivateTopicReg(message.topic)) {
                // todo Update Private Group Member Later.
                // GroupDataCenter.pullPrivateSubscribers(message.topic);
              } else {
                if (message.contentType == ContentType.eventSubscribe){
                  // add Member
                  Subscriber sub = Subscriber(
                      id: 0,
                      topic: message.topic,
                      chatId: message.from,
                      indexPermiPage: -1,
                      timeCreate: DateTime.now().millisecondsSinceEpoch,
                      blockHeightExpireAt: -1,
                      memberStatus: MemberStatus.MemberSubscribed);

                  SubscriberRepo().insertSubscriber(sub);
                }
                else if (message.contentType == ContentType.eventUnsubscribe){
                  // delete Member
                  GroupChatHelper.deleteSubscriberOfTopic(message.topic, message.from);
                }
                GroupDataCenter.pullSubscribersPublicChannel(message.topic);
              }
            }
          }
        }
        message.setMessageStatus(MessageStatus.MessageReceived);
        _insertMessage(message);
      }
    }

    /// Media Message
    if (message.contentType == ContentType.nknAudio ||
        message.contentType == ContentType.nknImage ||
        message.contentType == ContentType.media) {
      message.loadMedia(this);
    }

    if (message.topic != null) {
      /// Group Message
      if (message.contentType == ContentType.nknOnePiece) {
        NLog.w('Received nknOnePiece topic__'+message.topic.toString());
        _combineOnePieceMessage(message);
        return;
      }
      Topic topic = await GroupChatHelper.fetchTopicInfoByName(message.topic);
      if (topic == null) {
        bool meInChannel = await GroupChatPublicChannel.checkMeInChannel(
            message.topic, NKNClientCaller.currentChatId);
        NLog.w('Me in Channel is___'+meInChannel.toString());
        GroupDataCenter.pullSubscribersPublicChannel(message.topic);
        if (meInChannel == false) {
          return;
        } else {
          await GroupChatHelper.insertTopicIfNotExists(message.topic);
        }
      } else {
        bool existMember = await GroupChatHelper.checkMemberIsInGroup(
            message.from, message.topic);
        NLog.w('Exist no Member___' + existMember.toString());
        NLog.w('Exist no Member___' + message.from.toString());
        if (existMember == false) {
          /// insertMember
          /// do private logic
          if (topic.isPrivateTopic()){

          }
          else{
            Subscriber sub = Subscriber(
                id: 0,
                topic: message.topic.toString(),
                chatId: message.from.toString(),
                indexPermiPage: -1,
                timeCreate: DateTime.now().millisecondsSinceEpoch,
                blockHeightExpireAt: -1,
                memberStatus: MemberStatus.MemberSubscribed);

            SubscriberRepo().insertSubscriber(sub);
            await GroupDataCenter.pullSubscribersPublicChannel(message.topic);
          }
        }
      }
    } else {
      /// Single Message
      var contact = await _checkContactIfExists(message.from);
      if (message.contentType == ContentType.text ||
          message.contentType == ContentType.textExtension ||
          message.contentType == ContentType.media ||
          message.contentType == ContentType.nknImage ||
          message.contentType == ContentType.nknAudio) {
        // message.sendReceiptMessage();
        _checkBurnOptions(message, contact);
      } else if (message.contentType == ContentType.nknOnePiece) {
        _combineOnePieceMessage(message);
        return;
      }

      /// Operation Message
      else if (message.contentType == ContentType.contact) {
        Map<String, dynamic> data;
        try {
          data = jsonDecode(message.content);
        } on FormatException catch (e) {
          NLog.w('ContentType.contact Wrong!' + e.toString());
        }

        /// Receive Contact Request
        if (data['requestType'] != null) {
          ContactDataCenter.meResponseToProfile(contact, data);
        }

        /// Receive Contact Response
        else {
          if (data['onePieceReady'] != null) {
            String key = LocalStorage.NKN_ONE_PIECE_READY_JUDGE + message.from;
            LocalStorage().set(key, 'YES');
          }
          if (data['version'] == null) {
            NLog.w(
                'Unexpected Profile__No profile_version__' + data.toString());
          } else {
            /// do not have his contact
            NLog.w('Current Contact ProfileVersion is___' +
                contact.profileVersion.toString());
            if (data['responseType'] == RequestType.header) {
              await ContactDataCenter.setOrUpdateProfileVersion(contact, data);
            } else if (data['responseType'] == RequestType.full) {
              await contact.setOrUpdateExtraProfile(data);
              contactBloc.add(LoadContact(address: [contact.clientAddress]));
            } else {
              /// fit Version before 1.1.0
              if (data['content'] != null &&
                  (data['content']['name'] != null ||
                      data['content']['avatar'] != null)) {
                await contact.setOrUpdateExtraProfile(data);
                contactBloc.add(LoadContact(address: [contact.clientAddress]));
              } else {
                await ContactDataCenter.setOrUpdateProfileVersion(
                    contact, data);
              }
            }
          }
        }
      } else if (message.contentType == ContentType.eventContactOptions) {
        Map<String, dynamic> data;
        try {
          data = jsonDecode(message.content);
        } on FormatException catch (e) {
          NLog.w('ContentType.eventContactOptions E:' + e.toString());
        }
        if (data['optionType'] == 0 || data['optionType'] == '0') {
          _checkBurnOptions(message, contact);
          await contact.setBurnOptions(data['content']['deleteAfterSeconds']);
        } else {
          await contact.setDeviceToken(data['content']['deviceToken']);
        }
        contactBloc.add(LoadContact(address: [contact.clientAddress]));
      }
      else {
        NLog.w('Wrong!!! MessageType unhandled___' +
            message.contentType.toString());
      }
    }
    this.add(RefreshMessageListEvent());
    yield MessageUpdateState(target: message.from, message: message);
  }

  Stream<ChatState> _mapGetAndReadMessagesToState(
      GetAndReadMessages event) async* {
    if (event.target != null) {
      MessageSchema.getAndReadTargetMessages(event.target);
    }
    NLog.w('From _mapGetAndReadMessagesToState');
    yield MessageUpdateState(target: event.target);
  }

  /// change burn status
  _checkBurnOptions(MessageSchema message, ContactSchema contact) async {
    if (message.topic != null) return;

    if (message.deleteAfterSeconds != null) {
      if (message.contentType != ContentType.eventContactOptions){
        if (contact.options.updateBurnAfterTime == null ||
            message.timestamp.millisecondsSinceEpoch >
                contact.options.updateBurnAfterTime) {

          await contact.setBurnOptions(message.deleteAfterSeconds);
        }
      }
      NLog.w('contact.options is____' + contact.options.toJson());
    }
    NLog.w('!!!!contact._checkBurnOptions ___' +
        message.deleteAfterSeconds.toString());
    contactBloc.add(LoadContact(address: [contact.clientAddress]));
  }

  Future<ContactSchema> _checkContactIfExists(String clientAddress) async {
    var contact = await ContactSchema.fetchContactByAddress(clientAddress);
    if (contact == null) {
      /// need Test
      var walletAddress = await NknWalletPlugin.pubKeyToWalletAddr(
          getPublicKeyByClientAddr(clientAddress));

      if (clientAddress != null) {
        NLog.w('Insert contact stranger__' + clientAddress.toString());
      } else {
        NLog.w('got clientAddress Wrong!!!');
      }
      if (walletAddress == null) {
        NLog.w('got walletAddress Wrong!!!');
      }

      contact = ContactSchema(
          type: ContactType.stranger,
          clientAddress: clientAddress,
          nknWalletAddress: walletAddress);
      await contact.insertContact();
    }
    return contact;
  }

  /// check need send Notification
  Future<void> _checkIfSendNotification(String messageTo,String content) async {
    ContactSchema contact = await _checkContactIfExists(messageTo);

    String deviceToken = '';
    if (contact.deviceToken != null && contact.deviceToken.length > 0) {
      // String pushContent = NL10ns.of(Global.appContext).notification_push_content;
      String pushContent = 'New Message!';
      // pushContent = "from:"+accountChatId.substring(0, 8) + "...";
      // pushContent = 'You have New Message!';
      /// if no deviceToken means unable googleServiceOn is False
      /// GoogleServiceOn channel method can not be the judgement Because Huawei Device GoogleService is on true but not work!!!
      deviceToken = contact.deviceToken;
      if (deviceToken != null && deviceToken.length > 0) {
        NLog.w('Send Push notification content__' + deviceToken.toString());
        NKNClientCaller.nknPush(deviceToken,pushContent);
      }
    }
  }
}

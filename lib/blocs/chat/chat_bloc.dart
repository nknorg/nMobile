import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/chat/channel_members.dart';
import 'package:nmobile/blocs/contact/contact_bloc.dart';
import 'package:nmobile/blocs/contact/contact_event.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/local_notification.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/db/black_list_repo.dart';
import 'package:nmobile/model/db/subscriber_repo.dart';
import 'package:nmobile/model/db/topic_repo.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/model/group_chat_helper.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/log_tag.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> with Tag {
  @override
  ChatState get initialState => NoConnectState();
  final ContactBloc contactBloc;

  ChatBloc({@required this.contactBloc});

  /// This variable used to Check If the AndroidDevice got FCM Ability
  /// If so,there is no need to alert Notification while in ForegroundState by Android Device
  bool googleServiceOn =  false;
  bool googleServiceOnInit = false;

  @override
  Stream<ChatState> mapEventToState(ChatEvent event) async* {
    if (event is NKNChatOnMessageEvent) {
      yield OnConnectState();
    }
    else if (event is ReceiveMessageEvent) {
      yield* _mapReceiveMessageToState(event);
    }
    else if (event is SendMessageEvent) {
      yield* _mapSendMessageToState(event);
    }
    else if (event is RefreshMessageListEvent) {
      var unReadCount = await MessageSchema.unReadMessages();
      FlutterAppBadger.updateBadgeCount(unReadCount);
      yield MessageUpdateState(target: event.target);
    }
    else if (event is RefreshMessageEndEvent){
      yield MessageUpdateFinishState();
    }
    else if (event is GetAndReadMessages) {
      yield* _mapGetAndReadMessagesToState(event);
    }
  }

  Stream<ChatState> _mapSendMessageToState(SendMessageEvent event) async* {
    var message = event.message;

    if (message.topic == null) {
      _checkContactIfExists(message.to);
    }
    if (message.contentType == null){
      Global.debugLog('Content Type is null!!');
    }
    else{
      Global.debugLog('Content Type is__'+message.contentType.toString());
    }
    if (message.content == null){
      Global.debugLog('Message Content is null!!');
    }
    else{
      Global.debugLog('Message Content is__'+message.content.toString());
    }
    switch (message.contentType) {
      case ContentType.ChannelInvitation:
        message.isOutbound = true;
        message.isRead = true;
        try {
          var pid;
          NKNClientCaller.sendText([message.to], message.toTextData());
          pid = await NKNClientCaller.sendText([message.to], message.toTextData());
          message.pid = pid;
          message.isSendError = false;
        } catch (e) {
          message.isSendError = true;
        }
        break;
      case ContentType.text:
        message.isOutbound = true;
        message.isRead = true;
        try {
          var pid;
          if (message.topic != null) {
            pid = await _sendGroupMessage(message);
          } else {
            Map dataInfo = await _checkIfSendNotification(message);
            pid = await NKNClientCaller.sendText([message.to], jsonEncode(dataInfo));
          }
          message.pid = pid;
          message.isSendError = false;
        } catch (e) {
          message.isSendError = true;
        }
        break;
      case ContentType.textExtension:
        message.isOutbound = true;
        message.isRead = true;
        if (message.options != null && message.options['deleteAfterSeconds'] != null) {
          message.deleteTime = DateTime.now().add(Duration(seconds: message.options['deleteAfterSeconds']));
        }
        try {
          Map dataInfo = await _checkIfSendNotification(message);
          var pid = await NKNClientCaller.sendText([message.to], jsonEncode(dataInfo));
          message.pid = pid;
          message.isSendError = false;
        } catch (e) {
          message.isSendError = true;
        }
        break;
      case ContentType.nknImage:
      case ContentType.nknAudio:
        message.isOutbound = true;
        message.isRead = true;
        if (message.options != null && message.options['deleteAfterSeconds'] != null) {
          message.deleteTime = DateTime.now().add(Duration(seconds: message.options['deleteAfterSeconds']));
        }
        try {
          var pid;
          if (message.topic != null) {
            pid = await _sendGroupMessage(message);
          } else {
            String sendData = '';
            if (message.contentType == ContentType.nknImage){
              sendData = message.toImageData();
            }
            else if (message.contentType == ContentType.nknAudio){
              sendData = message.toAudioData();
            }
            pid = await NKNClientCaller.sendText([message.to], sendData);
          }
          message.pid = pid;
          message.isSendError = false;
        } catch (e) {
          message.isSendError = true;
        }
        break;
      case ContentType.eventContactOptions:
        try {
          await NKNClientCaller.sendText([message.to], message.toContentOptionData(message.contactOptionsType));
        } catch (e) {
          Global.debugLog('Receive Message eventContactOptions'+e.toString());
        }
        break;
      case ContentType.eventSubscribe:
        if (message.topic != null) {
          message.isOutbound = true;
          message.isRead = true;
          try {
            var pid;
            pid = await _sendGroupMessage(message);
            message.pid = pid;
            message.isSendError = false;
          } catch (e) {
            message.isSendError = true;
          }
        }
        break;
      case ContentType.eventUnsubscribe:
        if (message.topic != null) {
          message.isOutbound = true;
          message.isRead = true;
          try {
            var pid;
            pid = await _sendGroupMessage(message);
            message.pid = pid;
            message.isSendError = false;
          } catch (e) {
            message.isSendError = true;
          }
        }
        return;
    }
    await message.insert();
    if (message.contentType == ContentType.nknAudio){
      print('SendInsertAudioMessage__'+message.options.toString());
    }
    yield MessageUpdateState(target: message.to, message: message);
  }

  Future<Uint8List> _sendGroupMessage(MessageSchema message) async{
    Uint8List pid;
    String encodeSendJsonData;
    if (message.contentType == ContentType.text){
      encodeSendJsonData = message.toTextData();
    }
    else if (message.contentType == ContentType.nknImage){
      encodeSendJsonData = message.toImageData();
    }
    else if (message.contentType == ContentType.nknAudio){
      encodeSendJsonData = message.toAudioData();
    }
    else if (message.contentType == ContentType.eventSubscribe){
      encodeSendJsonData = message.toEventSubscribeData();
    }
    else if (message.contentType == ContentType.eventUnsubscribe){
      encodeSendJsonData = message.toEventUnSubscribeData();
    }
    if (isPrivateTopic(message.topic)) {
      List<String> dests = await GroupChatHelper.fetchGroupMembers(message.topic);
      if (dests != null && dests.length > 0){
        pid = await NKNClientCaller.sendText(dests, encodeSendJsonData);
      }
      else{
        Global.debugLog('Error no member__'+message.topic);
      }
    }
    else {
      List<String> members = await GroupChatHelper.fetchGroupMembers(message.topic);
      print('GroupMember is__'+members.toString());
      print('GroupMember count is__'+members.length.toString()+'__');
      pid = await NKNClientCaller.publishText(genTopicHash(message.topic), encodeSendJsonData);
      Global.debugLog('PublishText to Topic__'+message.topic+'__'+message.content);
    }
    return pid;
  }

  _judgeIfCanSendLocalMessageNotification(String title, MessageSchema message) async{
    if (Platform.isAndroid){
      if (googleServiceOnInit == false){
        if (Platform.isAndroid){
          googleServiceOn = await NKNClientCaller.googleServiceOn();
        }
        /// Android when have ability to use FCM, no longer need Local push
        if (googleServiceOn == false){
          LocalNotification.messageNotification(title, message.content, message: message);
        }
      }
    }
    else{
      LocalNotification.messageNotification(title, message.content, message: message);
    }
  }

  Stream<ChatState> _mapReceiveMessageToState(ReceiveMessageEvent event) async* {
    var message = event.message;
    print('Message received Begin');
    if (message.content != null){
      print('Receive Message'+message.content);
    }
    if (await message.isExist()) {
      Global.debugLog('message is not exists!');
      return;
    }

    Topic topic;
    if (message.topic != null){
      print('Receive Message from Topic'+message.topic);
      topic = await GroupChatHelper.fetchTopicInfoByName(message.topic);
      if (topic == null){
        /// check Block pool if the group contains Me If so, CreateGroup and join

        return;
      }
      else{
        /// Check If the Group contains the Member;
        bool existMember = await GroupChatHelper.checkMemberIsInGroup(message.from, message.topic);
        if (existMember == false){
          GroupChatPublicChannel.pullSubscribersPublicChannel(
            topicName: message.topic,
            membersBloc: BlocProvider.of<ChannelMembersBloc>(Global.appContext),
          );
        }
      }
    }

    /// message.topic is not null Means TopicChat
    var contact = await _checkContactIfExists(message.from);
    if (message.topic != null){
      Global.debugLog('GroupMessage from__'+message.from+'__'+message.topic);
    }
    else{
      Global.debugLog('SingleChat from__'+message.from);
    }

    final String title = (topic?.isPrivate ?? false) ? topic.shortName : contact.name;
    if (!contact.isMe && message.contentType != ContentType.contact && Global.isLoadProfile(contact.publicKey)) {
      if (contact.profileExpiresAt == null || DateTime.now().isAfter(contact.profileExpiresAt)) {
        Global.saveLoadProfile(contact.publicKey);
        contact.requestProfile();
      }
    }
    switch (message.contentType) {
      case ContentType.text:
        if (message.topic != null && message.from == NKNClientCaller.currentChatId) {
          await message.receiptTopic();
          message.isSuccess = true;
          message.isRead = true;
          message.content = message.msgId;
          message.contentType = ContentType.receipt;
          yield MessageUpdateState(target: message.from, message: message);
          return;
        }
        message.receipt();
        message.isSuccess = true;
        checkBurnOptions(message, contact);

        _judgeIfCanSendLocalMessageNotification(title, message);
        await message.insert();
        var unReadCount = await MessageSchema.unReadMessages();
        FlutterAppBadger.updateBadgeCount(unReadCount);

        yield MessageUpdateState(target: message.from, message: message);
        return;
      case ContentType.ChannelInvitation:
        message.receipt();
        message.isSuccess = true;
        _judgeIfCanSendLocalMessageNotification(title, message);
        await message.insert();
        var unReadCount = await MessageSchema.unReadMessages();
        FlutterAppBadger.updateBadgeCount(unReadCount);
        yield MessageUpdateState(target: message.from, message: message);
        return;
      case ContentType.receipt:
        // todo debug
        await message.receiptMessage();
        yield MessageUpdateState(target: message.from, message: message);
        return;
      case ContentType.textExtension:
        message.receipt();
        message.isSuccess = true;
        checkBurnOptions(message, contact);
        _judgeIfCanSendLocalMessageNotification(title, message);
        await message.insert();

        var unReadCount = await MessageSchema.unReadMessages();
        FlutterAppBadger.updateBadgeCount(unReadCount);
        yield MessageUpdateState(target: message.from, message: message);
        return;
      case ContentType.nknImage:
      case ContentType.nknAudio:
        if (message.topic != null && message.from == NKNClientCaller.currentChatId) {
          await message.receiptTopic();
          message.isSuccess = true;
          message.isRead = true;
          message.content = message.msgId;
          message.contentType = ContentType.receipt;
          yield MessageUpdateState(target: message.from, message: message);
          return;
        }
        message.receipt();
        message.isSuccess = true;
        checkBurnOptions(message, contact);
        _judgeIfCanSendLocalMessageNotification(title, message);
        message.loadMedia();
        await message.insert();
        var unReadCount = await MessageSchema.unReadMessages();
        FlutterAppBadger.updateBadgeCount(unReadCount);
        yield MessageUpdateState(target: message.from, message: message);
        return;
      case ContentType.contact:
        Map<String, dynamic> data;
        try {
          data = jsonDecode(message.content);
        }
        on FormatException catch (e) {
          Global.debugLog('ContentType.contact E:'+e.toString());
        }
        if (data['requestType'] == RequestType.header) {
          contact.responseProfile(type: RequestType.header);
        } else if (data['requestType'] == RequestType.full) {
          contact.responseProfile(type: RequestType.full);
        } else {
          if (data['version'] != contact.profileVersion) {
            if (data['content'] == null) {
              contact.requestProfile(type: RequestType.full);
            } else {
              await contact.setProfile(data);
              contactBloc.add(LoadContact(address: [message.from]));
            }
          }
        }
        return;
      case ContentType.eventContactOptions:
        Map<String, dynamic> data;
        try {
          data = jsonDecode(message.content);
        } on FormatException catch (e) {
          Global.debugLog('ContentType.eventContactOptions E:'+e.toString());
        }
        if (data['optionType'] == 0 || data['optionType'] == '0'){
          await contact.setBurnOptions(data['content']['deleteAfterSeconds']);
        }
        else{
          await contact.setDeviceToken(data['content']['deviceToken']);
        }
        contactBloc.add(LoadContact(address: [contact.clientAddress]));
        message.isSuccess = true;
        message.isRead = true;
        await message.insert();
        yield MessageUpdateState(target: message.from, message: message);
        return;
      case ContentType.eventSubscribe:
      case ContentType.eventUnsubscribe:
        Global.debugLog('Received ContentType.eventSubscribe__'+ContentType.eventSubscribe);

        Global.removeTopicCache(message.topic);
        if (message.from == NKNClientCaller.currentChatId) {
        } else {
          assert(message.topic.nonNull);
          if (isPrivateTopic(message.topic)) {
            print('PrivateGroup __'+ContentType.eventSubscribe);
            await GroupChatPrivateChannel.pullSubscribersPrivateChannel(
                topicName: message.topic,
                membersBloc: BlocProvider.of<ChannelMembersBloc>(Global.appContext),
                needUploadMetaCallback: (topicName) {
                  GroupChatPrivateChannel.uploadPermissionMeta(
                    topicName: topicName,
                    accountPubkey: NKNClientCaller.pubKey,
                    repoSub: SubscriberRepo(),
                    repoBlackL: BlackListRepo(),
                  );
                });
          } else {
            GroupChatPublicChannel.pullSubscribersPublicChannel(
              topicName: message.topic,
              myChatId: NKNClientCaller.currentChatId,
              membersBloc: BlocProvider.of<ChannelMembersBloc>(Global.appContext),
            );
          }
        }
        return;
    }
  }

  Stream<ChatState> _mapGetAndReadMessagesToState(GetAndReadMessages event) async* {
    if (event.target != null) {
      MessageSchema.getAndReadTargetMessages(event.target);
    }
    print('From _mapGetAndReadMessagesToState');
    yield MessageUpdateState(target: event.target);
  }

  ///change burn status
  checkBurnOptions(MessageSchema message, ContactSchema contact) async {
    if (message.topic != null) return;
    if (contact.options == null ||
        (contact.options.deleteAfterSeconds == null && message.deleteAfterSeconds != null) ||
        message.deleteAfterSeconds != contact.options.deleteAfterSeconds){
      await contact.setBurnOptions(message.deleteAfterSeconds);
    }
    contactBloc.add(LoadContact(address: [contact.clientAddress]));
  }

  Future<ContactSchema> _checkContactIfExists(String clientAddress) async {
    var contact = await ContactSchema.fetchContactByAddress(clientAddress);
    if (contact == null) {
      Global.debugLog('Insert contact stranger__'+clientAddress.toString());

      /// need Test
      var walletAddress = await NknWalletPlugin.pubKeyToWalletAddr(
      getPublicKeyByClientAddr(clientAddress));
      print('Insert contact__clientAddress__\n'+clientAddress+'walletAddress__\n'+walletAddress.toString());
      contact = ContactSchema(type: ContactType.stranger,
          clientAddress: clientAddress,
          nknWalletAddress: walletAddress);
      await contact.insertContact();
    }
    return contact;
  }

  /// check need send Notification
  Future<Map> _checkIfSendNotification(MessageSchema message) async{
    Map dataInfo;
    if (message.contentType == ContentType.text || message.contentType == ContentType.textExtension){
      dataInfo = jsonDecode(message.toTextData());
    }

    ContactSchema contact = await _checkContactIfExists(message.to);
    if (contact.deviceToken != null && contact.deviceToken.length > 0){
      String pushContent = NL10ns.of(Global.appContext).notification_push_content;
      pushContent = 'New Message!';
      // pushContent = "from:"+accountChatId.substring(0, 8) + "...";
      // pushContent = 'You have New Message!';
      Global.debugLog('Send Push notification content is '+pushContent);
      dataInfo['deviceToken'] = contact.deviceToken;
      dataInfo['pushContent'] = pushContent;

      if (message.contentType == ContentType.nknImage){
        dataInfo = jsonDecode(message.toImageData());
      }
      else if (message.contentType == ContentType.nknAudio){
        dataInfo = jsonDecode(message.toAudioData());
      }
      print('Send Message Data__'+dataInfo.toString());
    }
    return dataInfo;
  }
}

abstract class ChatState {
  const ChatState();
}

class NoConnectState extends ChatState {}

class OnConnectState extends ChatState {}

class MessageUpdateState extends ChatState {
  final String target;
  final MessageSchema message;

  const MessageUpdateState({this.target, this.message});
}

class MessageUpdateFinishState extends ChatState{

}

class GroupEvicted extends ChatState {
  final String topicName;

  const GroupEvicted(this.topicName);
}

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object> get props => [];
}

class NKNChatOnMessageEvent extends ChatEvent {}

class RefreshMessageListEvent extends ChatEvent {
  final String target;

  const RefreshMessageListEvent({this.target});
}

class RefreshMessageEndEvent extends ChatEvent{

}

class ReceiveMessageEvent extends ChatEvent {
  final MessageSchema message;

  const ReceiveMessageEvent(this.message);
}

class SendMessageEvent extends ChatEvent {
  final MessageSchema message;

  const SendMessageEvent(this.message);
}

class GetAndReadMessages extends ChatEvent {
  final String target;

  const GetAndReadMessages({this.target});
}

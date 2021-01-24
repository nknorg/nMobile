import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/chat/channel_members.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/blocs/chat/chat_state.dart';
import 'package:nmobile/blocs/contact/contact_bloc.dart';
import 'package:nmobile/blocs/contact/contact_event.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/local_notification.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/db/black_list_repo.dart';
import 'package:nmobile/model/db/nkn_data_manager.dart';
import 'package:nmobile/model/db/subscriber_repo.dart';
import 'package:nmobile/model/db/topic_repo.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/model/group_chat_helper.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> with Tag {
  @override
  ChatState get initialState => NoConnectState();
  final ContactBloc contactBloc;

  ChatBloc({@required this.contactBloc});

  /// This variable used to Check If the AndroidDevice got FCM Ability
  /// If so,there is no need to alert Notification while in ForegroundState by Android Device
  bool googleServiceOn =  false;
  bool googleServiceOnInit = false;

  List<MessageSchema> entityMessageList = new List();
  List<MessageSchema> actionMessageList = new List();
  Timer watchDog;
  int delayBatchSeconds = 3;

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
    else if (event is UpdateMessageEvent){
      /// Update MessageList and badge

      print('Insert IM From UpdateMessageEvent__ begin');

      var message = event.message;
      // message.setMessageStatus(MessageStatus.MessageReceived);
      // message.sendReceiptMessage();

      print('Insert IM From UpdateMessageEvent__'+message.content.toString());
      this.add(RefreshMessageListEvent());
      yield MessageUpdateState(message: message);
    }
    else if (event is GetAndReadMessages) {
      yield* _mapGetAndReadMessagesToState(event);
    }
  }

  _handleBatchMessage() async{
    /// Batch send ReceiptMessage
    /// Batch Insert MessageToDatabase
    Database cdb = await NKNDataManager.instance.currentDatabase();

    String batchId = '';
    Batch dbBatch = cdb.batch();
    for (MessageSchema message in entityMessageList){
      message.setMessageStatus(MessageStatus.MessageReceived);
      print('BatchInsert NormalMessageContent__'+message.content);
      batchId = batchId+','+message.msgId;

      dbBatch.insert(MessageSchema.tableName, message.toEntity(NKNClientCaller.pubKey));
    }
    List results = await dbBatch.commit();
    for(var resultString in results) {
      print('BatchInsertMessage__'+resultString.toString());
    }

    if (results.length > 0){
      print('BatchInsertMessage__Result__'+results.length.toString());
      var unReadCount = await MessageSchema.unReadMessages();
      FlutterAppBadger.updateBadgeCount(unReadCount);
    }
    for (MessageSchema message in entityMessageList){
      print('BatchMessage.isSuccess_'+message.isSuccess.toString());
      message.sendReceiptMessage();
    }
    if (entityMessageList.length > 500){
      entityMessageList.removeRange(0, 500);
      _sendBatchReceipt();
    }
    else{
      entityMessageList.clear();
    }
  }

  _sendBatchReceipt() async{
    if (entityMessageList.length > 500){
      _handleBatchMessage();
    }
    else if (entityMessageList.length > 10){
      _handleBatchMessage();
    }
    else {
      for (MessageSchema message in entityMessageList){
        print('Handle less10');
        bool insertS = await message.insertMessage();
        if(insertS){
          message.sendReceiptMessage();
        }
      }
      entityMessageList.clear();
    }
    this.add(RefreshMessageListEvent());
  }

  _addToBatchReceiveMessage(MessageSchema message){
    entityMessageList.add(message);

    delayBatchSeconds = 3;
    _startWatchDog();
  }

  _startWatchDog() {
    if (watchDog == null || watchDog.isActive == false){
      watchDog = Timer.periodic(Duration(milliseconds: 1000), (timer) {
        delayBatchSeconds--;
        if (delayBatchSeconds == 0){
          _stopWatchDog();
        }
        if (entityMessageList.length > 500){
          _sendBatchReceipt();
          print('entityMessageList > 500 ==> sendBatchReceipt');
        }
      });
    }
  }

  _stopWatchDog() {
    _sendBatchReceipt();
    print('_stopWatchDog > delayBatchSeconds==0 ==> sendBatchReceipt');
    delayBatchSeconds = 3;
    if(watchDog.isActive){
      watchDog.cancel();
      watchDog = null;
    }
  }

  Stream<ChatState> _mapSendMessageToState(SendMessageEvent event) async* {
    var message = event.message;

    _debugLogMessage(message,0);


    var pid;
    String contentData = '';
    message.setMessageStatus(MessageStatus.MessageSending);

    /// Handle GroupMessage Sending
    if (message.topic != null){
      pid = await _sendGroupMessage(message);
      if (pid != null){
        message.pid = pid;
        message.setMessageStatus(MessageStatus.MessageSendSuccess);
      }
      else{
        message.setMessageStatus(MessageStatus.MessageSendFail);
      }

      bool insertMessageBack = await message.insertMessage();
      print('InsertGroupMessageToDatabase___'+message.content+'___'+insertMessageBack.toString());

      yield MessageUpdateState(target: message.to, message: message);
      return;
    }
    /// Handle SingleMessage Sending
    else{
      if (message.contentType == ContentType.text ||
          message.contentType == ContentType.textExtension ||
          message.contentType == ContentType.nknImage ||
          message.contentType == ContentType.nknAudio){
        if (message.options != null && message.options['deleteAfterSeconds'] != null) {
          message.deleteTime = DateTime.now().add(Duration(seconds: message.options['deleteAfterSeconds']));
        }

        Map dataInfo = await _checkIfSendNotification(message);
        contentData = jsonEncode(dataInfo);
      }
      else if (message.contentType == ContentType.eventContactOptions) {
        contentData = message.toContentOptionData();
      }
      else if (message.contentType == ContentType.ChannelInvitation) {
        contentData = message.toTextData();
      }

      try {
        pid = await NKNClientCaller.sendText([message.to], contentData);
        message.pid = pid;
        print('SendMessageSuccess__'+message.contentType.toString()+'__'+message.to.toString());
        message.setMessageStatus(MessageStatus.MessageSendSuccess);
      }
      catch(e) {
        message.setMessageStatus(MessageStatus.MessageSendFail);
      }

    // case ContentType.eventContactOptions:
    //
    // break;
    // case ContentType.ChannelInvitation:
    // contentData = message.toTextData();
    // break;
    //   switch (message.contentType){
    //     case ContentType.text:
    //     case ContentType.nknImage:
    //     case ContentType.nknAudio:
    //       {
    //
    //         Map dataInfo = await _checkIfSendNotification(message);
    //         contentData = jsonEncode(dataInfo);
    //
    //         // contentData = message.toTextData();
    //       }
    //       break;
    //     case ContentType.textExtension:
    //       if (message.options != null && message.options['deleteAfterSeconds'] != null) {
    //         message.deleteTime = DateTime.now().add(Duration(seconds: message.options['deleteAfterSeconds']));
    //       }
    //       contentData = message.toTextData();
    //       break;
    //
    //
    //     default:
    //       print('Unhandled Message Type___'+message.contentType);
    //       break;
    //   }
    //
    //   // Map dataInfo = await _checkIfSendNotification(message);


    }
    bool insertMessageBack = await message.insertMessage();
    print('InsertMessageToDatabase___'+message.content+'___'+insertMessageBack.toString());

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
        try{
          pid = await NKNClientCaller.sendText(dests, encodeSendJsonData);
        }
        catch(e){
          print('PrivateGroup Message SendFail____'+e.toString());
          return null;
        }
      }
      else{
        Global.debugLog('Error no member__'+message.topic);
      }
    }
    else {
      List<String> members = await GroupChatHelper.fetchGroupMembers(message.topic);
      print('GroupMember count is__'+members.length.toString()+'__');
      try{
        pid = await NKNClientCaller.publishText(genTopicHash(message.topic), encodeSendJsonData);
        print('Publish Message toGroupSuccess__'+message.content.toString());
      }
      catch(e){
        print('PublishMessage SendFail____'+e.toString());
        return null;
      }
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

  _debugLogMessage(MessageSchema message,int type){
    String typeString = 'Sending_____\n';
    if (type == 1){
      typeString = 'Received_____\n';
    }
    if (message.contentType != null){
      Global.debugLog('$typeString'+'Message ContentType is___'+message.contentType.toString());
    }
    if (message.topic != null){
      Global.debugLog('$typeString'+'Message Topic is___'+message.topic.toString());
    }
    if (message.content != null){
      Global.debugLog('$typeString'+'Message Content is___'+message.content.toString());
    }
    if (message.from != null){
      Global.debugLog('$typeString'+'Message From is___'+message.from.toString());
    }
  }

  _handleEntityMessage(MessageSchema message) async{
    DateTime nDate = DateTime.now();
    int timeGap = nDate.millisecondsSinceEpoch - message.timestamp.millisecondsSinceEpoch;
    print('timeGap is___'+timeGap.toString());

    /// Consider as OnlineMessage,If not consider the User is offline
    if (timeGap/1000 < 5*60){
      bool insertReceiveSuccess = await message.insertMessage();
      if (insertReceiveSuccess){
        message.setMessageStatus(MessageStatus.MessageReceived);
        message.sendReceiptMessage();

        print('Insert IM Received Message__'+message.content);
        var unReadCount = await MessageSchema.unReadMessages();
        FlutterAppBadger.updateBadgeCount(unReadCount);
        this.add(RefreshMessageListEvent());
        this.add(UpdateMessageEvent(message));
      }
    }
    else{
      _addToBatchReceiveMessage(message);
    }
  }

  Stream<ChatState> _mapReceiveMessageToState(ReceiveMessageEvent event) async* {
    var message = event.message;
    _debugLogMessage(message,1);

    if (await message.isExist()) {
      print('ReceiveMessage from AnotherNode__');
      return;
    }

    Topic topic;
    /// message.topic is not null Means TopicChat
    if (message.topic != null){
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
        else{
          /// If Received self Send
          if (message.from == NKNClientCaller.pubKey){
            message.receiptTopic();
            message.setMessageStatus(MessageStatus.MessageSendReceipt);
            yield MessageUpdateState(target: message.from, message: message);
            return;
          }

          if (message.contentType == ContentType.text ||
              message.contentType == ContentType.textExtension ||
              message.contentType == ContentType.nknAudio ||
              message.contentType == ContentType.nknImage){
            if (message.contentType == ContentType.nknImage ||
                message.contentType == ContentType.nknAudio){
              message.loadMedia(this);
              print('message LoadMedia'+message.contentType);
            }

            _handleEntityMessage(message);
            yield MessageUpdateState(target: message.from, message: message);
          }
        }
      }
    }
    else{
      var contact = await _checkContactIfExists(message.from);

      if (message.contentType == ContentType.eventContactOptions){
        _checkBurnOptions(message, contact);
      }
      if (message.contentType == ContentType.text ||
          message.contentType == ContentType.textExtension ||
          message.contentType == ContentType.nknImage ||
          message.contentType == ContentType.nknAudio){
        _checkBurnOptions(message, contact);

        if (message.contentType == ContentType.nknImage ||
            message.contentType == ContentType.nknAudio){
          message.loadMedia(this);
          print('message LoadMedia'+message.contentType);
        }

        _handleEntityMessage(message);
        yield MessageUpdateState(target: message.from, message: message);
        return;
      }

      if (message.contentType == ContentType.contact){
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
      }
      if (message.contentType == ContentType.eventContactOptions){
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
      }

      if (message.contentType == ContentType.eventSubscribe ||
          message.contentType == ContentType.eventUnsubscribe){
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
      }

      /// Receipt sendMessage do not need InsertToDataBase
      if (message.contentType == ContentType.receipt){
        message.receiptMessage();
        print('Received ReceiptMessage');
      }
      else{
        if (message.contentType == ContentType.text ||
        message.contentType == ContentType.textExtension ||
        message.contentType == ContentType.nknImage ||
        message.contentType == ContentType.nknAudio){
          yield MessageUpdateState(target: message.from, message: message);
        }
        else{
          print('Enter Old Logic');
          print('__message.contentType__'+ message.contentType.toString());
          /// loadUserProfile
          // final String title = (topic?.isPrivate ?? false) ? topic.shortName : contact.name;
          // if (!contact.isMe && message.contentType != ContentType.contact && Global.isLoadProfile(contact.publicKey)) {
          //   if (contact.profileExpiresAt == null || DateTime.now().isAfter(contact.profileExpiresAt)) {
          //     Global.saveLoadProfile(contact.publicKey);
          //     contact.requestProfile();
          //   }
          // }
          // _judgeIfCanSendLocalMessageNotification(title, message);
          //
          // bool insertReceiveSuccess = await message.insertMessage();
          // if (insertReceiveSuccess){
          //   message.setMessageStatus(MessageStatus.MessageReceived);
          //   message.sendReceiptMessage();
          //
          //   print('Insert NormalMessage__'+message.content);
          //   var unReadCount = await MessageSchema.unReadMessages();
          //   FlutterAppBadger.updateBadgeCount(unReadCount);
          // }
          // else{
          //   showToast('Inert database failed');
          // }
        }
      }
      yield MessageUpdateState(target: message.from, message: message);
    }
  }

  Stream<ChatState> _mapGetAndReadMessagesToState(GetAndReadMessages event) async* {
    if (event.target != null) {
      MessageSchema.getAndReadTargetMessages(event.target);
    }
    print('From _mapGetAndReadMessagesToState');
    yield MessageUpdateState(target: event.target);
  }

  /// change burn status
  _checkBurnOptions(MessageSchema message, ContactSchema contact) async {
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
    else if (message.contentType == ContentType.nknImage){
      dataInfo = jsonDecode(message.toImageData());
    }
    else if (message.contentType == ContentType.nknAudio){
      dataInfo = jsonDecode(message.toAudioData());
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
    }

    return dataInfo;
  }
}

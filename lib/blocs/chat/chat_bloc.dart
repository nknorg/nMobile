import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_reed_solomon/dart_reed_solomon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mime_type/mime_type.dart';
import 'package:nmobile/blocs/chat/channel_bloc.dart';
import 'package:nmobile/blocs/chat/chat_event.dart';
import 'package:nmobile/blocs/chat/chat_state.dart';
import 'package:nmobile/blocs/contact/contact_bloc.dart';
import 'package:nmobile/blocs/contact/contact_event.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/local_notification.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/model/db/black_list_repo.dart';
import 'package:nmobile/model/db/message_data_center.dart';
import 'package:nmobile/model/db/nkn_data_manager.dart';
import 'package:nmobile/model/db/subscriber_repo.dart';
import 'package:nmobile/model/db/topic_repo.dart';
import 'package:nmobile/plugins/nkn_wallet.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/model/group_chat_helper.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/utils/extensions.dart';
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
  bool googleServiceOn =  false;
  bool googleServiceOnInit = false;

  List<MessageSchema> entityMessageList = new List();
  List<MessageSchema> actionMessageList = new List();
  Timer watchDog;
  int delayResendSeconds = 15;

  Map judgeToResendMessage = new Map();

  Uint8List messageIn, messageOut;

  bool useOnePiece = true;
  int perPieceLength = 1024*4;

  // ReedSolomon reedSolomon = ReedSolomon(
  //   symbolSizeInBits: 6,
  //   numberOfCorrectableSymbols: 6,
  //   primitivePolynomial: 4096,
  //   initialRoot: 1,
  // );

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
    else if (event is RefreshMessageChatEvent){
      yield MessageUpdateState(target: event.message.to, message: event.message);
    }
    else if (event is UpdateChatEvent){
      String targetId = event.targetId;
      
      var res = await MessageSchema.getAndReadTargetMessages(targetId, limit: 20);
      this.add(RefreshMessageListEvent(target: targetId));
      yield UpdateChatMessageState(res);
    }
    else if (event is GetAndReadMessages) {
      yield* _mapGetAndReadMessagesToState(event);
    }
  }

  _resendMessage(MessageSchema message) async{
    var cdb = await NKNDataManager().currentDatabase();

    var res = await cdb.query(
      MessageSchema.tableName,
      columns: ['*'],
      orderBy: 'send_time desc',
      where: 'sender = ? AND receiver = ? '
          'AND is_success = 0 AND NOT type = ? '
          'AND NOT type = ? AND NOT type = ? '
          'AND NOT type = ?',
      whereArgs: [message.to,message.from,
        ContentType.nknOnePiece, ContentType.eventContactOptions,
        ContentType.eventSubscribe,ContentType.eventUnsubscribe],
      limit: 20,
      offset: 0,
    );

    List<MessageSchema> messages = <MessageSchema>[];
    for (var i = 0; i < res.length; i++) {
      var messageItem = MessageSchema.parseEntity(res[i]);
      messages.add(messageItem);
    }
    if (res.isNotEmpty){
      NLog.w('ResendMessage___'+res.length.toString());
      for (MessageSchema message in messages){
        if (message.isSuccess == false && message.isSendMessage()){
          this.add(SendMessageEvent(message));
        }
      }
    }
  }

  _judgeResend() async{
    /// Query UnreadMessage and resend it to the very ClientAddress
    if (delayResendSeconds == 0){
      for (String key in judgeToResendMessage.keys){
        MessageSchema message = judgeToResendMessage[key];
        _resendMessage(message);
      }

      _stopWatchDog();
    }
    delayResendSeconds--;
  }

  _startWatchDog(MessageSchema msg) {
    if (watchDog == null || watchDog.isActive == false){
      /// because it is Receipt message, so keep msg.from
      if (!judgeToResendMessage.containsKey(msg.from)){
        judgeToResendMessage[msg.from] = msg;
      }

      delayResendSeconds = 15;
      watchDog = Timer.periodic(Duration(milliseconds: 1000), (timer) async {
        _judgeResend();
      });
    }
  }

  _stopWatchDog() {
    print('_stopWatchDog > delayResend ==0 ==> ');
    delayResendSeconds = 15;
    if(watchDog.isActive){
      watchDog.cancel();
      watchDog = null;
    }
  }

  _watchSendMessage(MessageSchema message) async{
    bool pidExists = await MessageDataCenter.judgeMessagePid(message.msgId);
    if (pidExists == false){
      message.setMessageStatus(MessageStatus.MessageSendFail);
    }
  }

  Stream<ChatState> _mapSendMessageToState(SendMessageEvent event) async* {
    var message = event.message;

    // Uint8List pid;
    String contentData = '';
    await message.insertSendMessage();

    // Timer(Duration(seconds: 11), () {
    //   _watchSendMessage(message);
    // });
    /// Handle GroupMessage Sending
    if (message.topic != null){
      try {
        _sendGroupMessage(message);
        // message.setMessageStatus(MessageStatus.MessageSending);
      }
      catch(e) {
        // message.setMessageStatus(MessageStatus.MessageSendFail);
      }

      yield MessageUpdateState(target: message.to, message: message);
      return;
    }
    /// Handle SingleMessage Sending
    else{
      if (message.contentType == ContentType.text ||
          message.contentType == ContentType.textExtension ||
          message.contentType == ContentType.nknAudio ||
          message.contentType == ContentType.media ||
          message.contentType == ContentType.nknImage) {
        if (message.options != null && message.options['deleteAfterSeconds'] != null) {
          message.deleteTime = DateTime.now().add(Duration(seconds: message.options['deleteAfterSeconds']));
          await message.updateDeleteTime();
        }
        if (useOnePiece && (message.contentType == ContentType.nknAudio ||
                message.contentType == ContentType.media ||
                message.contentType == ContentType.nknImage)) {
          _sendOnePieceMessage(message);
          return;
        }
        else{
          contentData = await _checkIfSendNotification(message);
        }
      }
      else if (message.contentType == ContentType.nknOnePiece){
        contentData = message.toNknPieceMessageData();
      }
      else if (message.contentType == ContentType.eventContactOptions) {
        contentData = message.content;
      }
      else if (message.contentType == ContentType.channelInvitation) {
        contentData = await _checkIfSendNotification(message);
      }

      if (_judgeShowReconnect() == false){
        try{
          Uint8List pid = await NKNClientCaller.sendText([message.to], contentData, message.msgId);

          NLog.w('Pid is-__'+pid.toString());
          MessageDataCenter.updateMessagePid(pid, message.msgId);
        }
        catch(e){
          NLog.w('Wrong___'+e.toString());
          message.setMessageStatus(MessageStatus.MessageSendFail);
        }
      }
    }

    this.add(RefreshMessageListEvent());
    yield MessageUpdateState(target: message.to, message: message);
  }

  bool _judgeShowReconnect(){
    return false;
  }

  _combineOnePieceMessage(MessageSchema onePieceMessage) async{
    bool exist = await onePieceMessage.existOnePieceIndex();
    if (exist){
      return;
    }
    var bytes = base64Decode(onePieceMessage.content);
    if (bytes.length > perPieceLength){
      perPieceLength = bytes.length;
    }
    String name = hexEncode(md5
        .convert(bytes)
        .bytes);

    String path = getCachePath(NKNClientCaller.currentChatId);

    String filePath = join(path, name+'.'+onePieceMessage.parentType.toString());
    File file = File(filePath);

    file.writeAsBytesSync(bytes,flush: true);

    onePieceMessage.content = file;
    NLog.w('Saved before onePiece option is___'+onePieceMessage.options.toString());
    NLog.w('Saved before onePiece option is___'+onePieceMessage.audioFileDuration.toString());
    onePieceMessage.options = {
      'index': onePieceMessage.index,
      'total': onePieceMessage.total,
      'parentType': onePieceMessage.parentType,
      'deleteAfterSeconds': onePieceMessage.deleteAfterSeconds,
      'audioDuration': onePieceMessage.audioFileDuration,
    };
    await onePieceMessage.insertOnePieceMessage();

    int total = onePieceMessage.total;
    int receivedOnePieces = await onePieceMessage.onePieceCount();

    bool existFull = await onePieceMessage.existFullPiece();
    if (existFull){
      NLog.w('_combineOnePieceMessage existOnePiece___'+onePieceMessage.msgId);
      return;
    }
    if (total == receivedOnePieces){
      List allPieces = await onePieceMessage.allPieces();
      print('allPieces length is__'+allPieces.length.toString());

      for (MessageSchema schema in allPieces){
        if (schema.index == 0){
          MessageSchema onePiece = schema;
          File file = onePiece.content as File;
          Uint8List fBytes = file.readAsBytesSync();
          perPieceLength = fBytes.length;
        }
      }

      Uint8List fullBytes = Uint8List(allPieces.length*perPieceLength);

      String extension = '';
      if (onePieceMessage.parentType == ContentType.nknImage ||
          onePieceMessage.parentType == ContentType.media){
        extension = 'jpeg';
      }
      else if (onePieceMessage.parentType == ContentType.nknAudio){
        extension = 'aac';
      }

      for (int i = 0; i < allPieces.length; i++){
        MessageSchema onePiece;

        for (MessageSchema schema in allPieces){
          if (schema.index == i){
            onePiece = schema;
          }
        }

        File file = onePiece.content as File;

        Uint8List fBytes = file.readAsBytesSync();

        int startIndex = i*perPieceLength;
        int endIndex = startIndex+fBytes.length;
        fullBytes.setRange(startIndex, endIndex, fBytes);
      }
      /// Write full content Message to file
      NLog.w('fullSize is__'+fullBytes.length.toString());
      String name = hexEncode(md5
          .convert(fullBytes)
          .bytes);
      String fullPath = getCachePath(NKNClientCaller.currentChatId);
      File fullFile = File(join(fullPath, name + '.$extension'));
      NLog.w('FullFile is___'+fullFile.path);

      NLog.w('delete seconds is___'+onePieceMessage.deleteAfterSeconds.toString());

      fullFile.writeAsBytes(fullBytes, flush: true);

      Duration deleteAfterSeconds;
      if (onePieceMessage.deleteAfterSeconds != null){
        deleteAfterSeconds = Duration(seconds: onePieceMessage.deleteAfterSeconds);
      }

      MessageSchema nReceived =  MessageSchema.formReceivedMessage(
        msgId: onePieceMessage.msgId,
        from: onePieceMessage.from,
        to: onePieceMessage.to,
        pid: onePieceMessage.pid,
        contentType: onePieceMessage.parentType,
        content: fullFile,
        audioFileDuration: onePieceMessage.audioFileDuration,
      );

      nReceived.options = onePieceMessage.options;
      if (onePieceMessage.options != null && onePieceMessage.options['deleteAfterSeconds'] != null) {
        nReceived.deleteTime = DateTime.now().add(Duration(seconds: onePieceMessage.options['deleteAfterSeconds']));
      }

      await nReceived.insertReceivedMessage();
      nReceived.setMessageStatus(MessageStatus.MessageReceived);
      nReceived.sendReceiptMessage();

      this.add(RefreshMessageListEvent());
      this.add(RefreshMessageChatEvent(nReceived));
    }
  }

  _sendOnePiece(List mpList,MessageSchema parentMessage) async{
    for (int index = 0; index < mpList.length; index++){
      Uint8List fileP = mpList[index];

      Duration deleteAfterSeconds;
      ContactSchema contact = await _checkContactIfExists(parentMessage.to);
      if (contact?.options != null) {
        if (contact?.options?.deleteAfterSeconds != null) {
          deleteAfterSeconds = Duration(seconds: contact.options.deleteAfterSeconds);
        }
      }
      String content = base64Encode(fileP);

      Duration duration = Duration(milliseconds: index*100);
      Timer(duration, () async {
        var nknOnePieceMessage = MessageSchema.fromSendData(
          msgId: parentMessage.msgId,
          from: parentMessage.from,
          to: parentMessage.to,
          parentType: parentMessage.contentType,
          content: content,
          contentType: ContentType.nknOnePiece,
          index: index,
          total: mpList.length,
          deleteAfterSeconds: deleteAfterSeconds,
          audioFileDuration: parentMessage.audioFileDuration,
        );
        NLog.w('Send OnePiece with index__'+index.toString()+'__');
        this.add(SendMessageEvent(nknOnePieceMessage));
      });
    }
  }

  _sendOnePieceMessage(MessageSchema message) async{
    File file = message.content as File;
    var mimeType = mime(file.path);
    String content;

    NLog.w('mime Type is____'+mimeType.toString());
    if (mimeType.indexOf('image') > -1 ||
        mimeType.indexOf('audio') > -1) {
      List fileBytesList = file.readAsBytesSync();


      int filePieces = fileBytesList.length~/(perPieceLength);
      int leftPiece = fileBytesList.length%(perPieceLength);
      if (leftPiece > 0){
        filePieces += 1;
      }
      List filePieceList = new List();
      for (int i = 0; i < filePieces; i++){
        int startIndex = i*perPieceLength;
        int endIndex = (i+1)*perPieceLength;
        if (endIndex > fileBytesList.length){
          endIndex = fileBytesList.length;
        }

        Uint8List fileP = fileBytesList.sublist(startIndex,endIndex);
        filePieceList.add(fileP);
      }

      NLog.w('_sendOnePieceMessage__'+filePieceList.length.toString());
      _sendOnePiece(filePieceList, message);
    }
  }

  _sendGroupMessage(MessageSchema message) async{
    String encodeSendJsonData;
    if (message.contentType == ContentType.text){
      encodeSendJsonData = message.toTextData(null);
    }
    else if (message.contentType == ContentType.nknImage ||
             message.contentType == ContentType.media){
      encodeSendJsonData = message.toImageData(null);
    }
    else if (message.contentType == ContentType.nknAudio){
      encodeSendJsonData = message.toAudioData(null);
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
        if (_judgeShowReconnect() == false){
          Uint8List pid = await NKNClientCaller.sendText(dests, encodeSendJsonData, message.msgId);
          MessageDataCenter.updateMessagePid(pid, message.msgId);
        }
      }
      else{
        if (message.topic != null){
          NLog.w('Wrong !!!Topic got no Member'+message.topic);
        }
      }
    }
    else {
      if (_judgeShowReconnect() == false){
        Uint8List pid;
        try{
          pid = await NKNClientCaller.publishText(genTopicHash(message.topic), encodeSendJsonData);
          message.setMessageStatus(MessageStatus.MessageSendSuccess);
        }
        catch(e){
          message.setMessageStatus(MessageStatus.MessageSendFail);
        }
        if (pid != null) {
          MessageDataCenter.updateMessagePid(pid, message.msgId);
        }
      }
    }
  }

  _judgeIfCanSendLocalMessageNotification(String title, MessageSchema message) async{

    // final String title = (topic?.isPrivate ?? false) ? topic.shortName : contact.name;


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

  _insertMessage(MessageSchema message) async{
    bool insertReceiveSuccess = await message.insertReceivedMessage();
    if (insertReceiveSuccess){
      message.setMessageStatus(MessageStatus.MessageReceived);
      message.sendReceiptMessage();
      NLog.w('Received_______!!!!!!!!!0');

      var unReadCount = await MessageSchema.unReadMessages();
      FlutterAppBadger.updateBadgeCount(unReadCount);
    }
    else{
      NLog.w('Insert Message failed'+message.contentType.toString());
    }
  }

  Stream<ChatState> _mapReceiveMessageToState(ReceiveMessageEvent event) async* {
    var message = event.message;

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

    /// todo Need Check
    ContactSchema contact = await _checkContactIfExists(message.from);
    if (!contact.isMe && message.contentType != ContentType.contact &&
        Global.isLoadProfile(contact.publicKey)) {
      if (contact.profileExpiresAt == null ||
          DateTime.now().isAfter(contact.profileExpiresAt)) {
        Global.saveLoadProfile(contact.publicKey);
        contact.requestProfile(RequestType.header);
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
        message.receiptTopic();

        message.content = message.msgId;
        message.contentType = ContentType.receipt;
        message.topic = null;

        yield MessageUpdateState(target: message.from, message: message);
        return;
      }
      else{
        message.setMessageStatus(MessageStatus.MessageReceived);
        NLog.w('Received_______!!!!!!!!!1');
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
      Topic topic = await GroupChatHelper.fetchTopicInfoByName(message.topic);

      if (topic == null) {
        await GroupChatHelper.insertTopicIfNotExists(message.topic);

        GroupChatPublicChannel.pullSubscribersPublicChannel(
          topicName: message.topic,
          membersBloc: BlocProvider.of<ChannelBloc>(Global.appContext),
        );
      }
      else {
        bool existMember = await GroupChatHelper.checkMemberIsInGroup(
            message.from, message.topic);
        if (existMember == false) {
          NLog.w('Exist no Member___' + message.from.toString());

          /// insertMember
          Subscriber sub = Subscriber(
              id: 0,
              topic: message.topic.toString(),
              chatId: message.from.toString(),
              indexPermiPage: -1,
              timeCreate: DateTime
                  .now()
                  .millisecondsSinceEpoch,
              blockHeightExpireAt: -1,
              uploaded: true,
              subscribed: true,
              uploadDone: true);

          await GroupChatHelper.insertSubscriber(sub);
          GroupChatPublicChannel.pullSubscribersPublicChannel(
            topicName: message.topic,
            membersBloc: BlocProvider.of<ChannelBloc>(Global.appContext),
          );
        }
      }
    }
    else {
      /// Single Message
      var contact = await _checkContactIfExists(message.from);
      if (message.contentType == ContentType.text ||
          message.contentType == ContentType.textExtension ||
          message.contentType == ContentType.media ||
          message.contentType == ContentType.nknImage ||
          message.contentType == ContentType.nknAudio) {
        // message.sendReceiptMessage();
        _checkBurnOptions(message, contact);
      }
      else if (message.contentType == ContentType.nknOnePiece) {
        _combineOnePieceMessage(message);
        return;
      }
      /// Operation Message
      else if (message.contentType == ContentType.contact) {
        Map<String, dynamic> data;
        try {
          data = jsonDecode(message.content);
        }
        on FormatException catch (e) {
          NLog.w('ContentType.contact Wrong!' + e.toString());
        }

        /// Receive Contact Request
        if (data['requestType'] != null) {
          contact.responseProfile(data);
        }
        /// Receive Contact Response
        else {
          if (data['version'] != contact.profileVersion) {
            if (data['responseType'] == RequestType.header) {
              await contact.setOrUpdateProfileVersion(data);
            }
            else if (data['responseType'] == RequestType.full) {
              await contact.setOrUpdateExtraProfile(data);
            }
            if (data['content'] == null) {
              contact.requestProfile(RequestType.full);
            }
            else {
              await contact.setOrUpdateExtraProfile(data);
              contactBloc.add(LoadContact(address: [message.from]));
            }
          }
          else {
            NLog.w('Wrong!!!!! contactVersion is' +
                contact.profileVersion.toString());
            NLog.w('Wrong!!!!! dataVersion is' + data['version'].toString());
          }
        }
      }
      else if (message.contentType == ContentType.eventContactOptions) {
        Map<String, dynamic> data;
        try {
          data = jsonDecode(message.content);
        } on FormatException catch (e) {
          NLog.w('ContentType.eventContactOptions E:' + e.toString());
        }
        if (data['optionType'] == 0 || data['optionType'] == '0') {
          _checkBurnOptions(message, contact);
          await contact.setBurnOptions(data['content']['deleteAfterSeconds']);
        }
        else {
          await contact.setDeviceToken(data['content']['deviceToken']);
        }
        contactBloc.add(LoadContact(address: [contact.clientAddress]));
      }
      else if (message.contentType == ContentType.eventSubscribe ||
          message.contentType == ContentType.eventUnsubscribe) {
        if (message.from == NKNClientCaller.currentChatId) {} else {
          assert(message.topic.nonNull);
          if (isPrivateTopic(message.topic)) {
            await GroupChatPrivateChannel.pullSubscribersPrivateChannel(
                topicName: message.topic,
                membersBloc: BlocProvider.of<ChannelBloc>(Global.appContext),
                needUploadMetaCallback: (topicName) {
                  GroupChatPrivateChannel.uploadPermissionMeta(
                    topicName: topicName,
                    accountPubkey: NKNClientCaller.currentChatId,
                    repoSub: SubscriberRepo(),
                    repoBlackL: BlackListRepo(),
                  );
                });
          } else {
            GroupChatPublicChannel.pullSubscribersPublicChannel(
              topicName: message.topic,
              myChatId: NKNClientCaller.currentChatId,
              membersBloc: BlocProvider.of<ChannelBloc>(Global.appContext),
            );
          }
        }
      }

      /// Receipt sendMessage do not need InsertToDataBase
      else if (message.contentType == ContentType.receipt) {
        int count = await message.receiptMessage();
        message.setMessageStatus(MessageStatus.MessageSendReceipt);

        if (count == 0) {
          print('Duplicate insert');
          message.insertReceivedMessage();
        }
        _startWatchDog(message);
      }
      else {
        NLog.w('Wrong!!! MessageType unhandled___'+message.contentType.toString());
      }
    }
    this.add(RefreshMessageListEvent());
    yield MessageUpdateState(target: message.from, message: message);
  }

  Stream<ChatState> _mapGetAndReadMessagesToState(GetAndReadMessages event) async* {
    if (event.target != null) {
      MessageSchema.getAndReadTargetMessages(event.target);
    }
    NLog.w('From _mapGetAndReadMessagesToState');
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
      /// need Test
      var walletAddress = await NknWalletPlugin.pubKeyToWalletAddr(getPublicKeyByClientAddr(clientAddress));

      if (clientAddress != null){
        NLog.w('Insert contact stranger__'+clientAddress.toString());
      }
      else{
        NLog.w('got clientAddress Wrong!!!');
      }
      if (walletAddress == null){
        NLog.w('got walletAddress Wrong!!!');
      }

      contact = ContactSchema(type: ContactType.stranger,
          clientAddress: clientAddress,
          nknWalletAddress: walletAddress);
      await contact.insertContact();
    }
    return contact;
  }

  /// check need send Notification
  Future<String> _checkIfSendNotification(MessageSchema message) async{
    Map dataInfo;
    ContactSchema contact = await _checkContactIfExists(message.to);

    if (contact.deviceToken != null && contact.deviceToken.length > 0){
      // String pushContent = NL10ns.of(Global.appContext).notification_push_content;
      String pushContent = 'New Message!';
      // pushContent = "from:"+accountChatId.substring(0, 8) + "...";
      // pushContent = 'You have New Message!';

      if (pushContent != null && pushContent.length > 0){
        NLog.w('Send Push notification content__'+pushContent);
      }
      dataInfo = new Map();
      dataInfo['deviceToken'] = contact.deviceToken;
      dataInfo['pushContent'] = pushContent;
    }

    String sendContent = '';
    if (message.contentType == ContentType.text ||
        message.contentType == ContentType.textExtension ||
        message.contentType == ContentType.channelInvitation) {
      sendContent = message.toTextData(dataInfo);
    }
    else if (message.contentType == ContentType.nknImage ||
        message.contentType == ContentType.media){
      sendContent = message.toImageData(dataInfo);
    }
    else if (message.contentType == ContentType.nknAudio){
      sendContent = message.toAudioData(dataInfo);
    }
    return sendContent;
  }
}

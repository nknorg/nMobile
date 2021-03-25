import 'package:bloc/bloc.dart';
import 'package:nmobile/blocs/channel/channel_event.dart';
import 'package:nmobile/blocs/channel/channel_state.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/model/datacenter/contact_data_center.dart';
import 'package:nmobile/model/datacenter/group_data_center.dart';
import 'package:nmobile/model/entity/subscriber_repo.dart';
import 'package:nmobile/model/entity/contact.dart';
import 'package:nmobile/screens/chat/channel_members.dart';
import 'package:nmobile/utils/nlog_util.dart';

class ChannelBloc extends Bloc<ChannelMembersEvent, ChannelState> {
  @override
  ChannelState get initialState => ChannelUpdateState();

  @override
  Stream<ChannelState> mapEventToState(ChannelMembersEvent event) async* {
    if (event is ChannelOwnMemberCountEvent) {
      String topicName = event.topicName;
      int inviteCount = await GroupDataCenter().getCountOfTopic(topicName, MemberStatus.MemberInvited);
      int publishedCount = await GroupDataCenter().getCountOfTopic(topicName, MemberStatus.MemberPublished);
      int joinedCount = await GroupDataCenter().getCountOfTopic(topicName, MemberStatus.MemberSubscribed);
      int rejectCount = await GroupDataCenter().getCountOfTopic(topicName, MemberStatus.MemberPublishRejected);

      yield ChannelOwnMembersState(inviteCount+publishedCount,joinedCount,rejectCount,topicName);
    }
    else if (event is ChannelMemberCountEvent){
      String topicName = event.topicName;
      int count = await GroupDataCenter().getCountOfTopic(topicName,MemberStatus.MemberSubscribed);
      yield ChannelMembersState(count, topicName);
    }
    else if (event is FetchChannelMembersEvent) {
      yield* _mapFetchMembersEvent(event);
    }
    else if (event is FetchOwnChannelMembersEvent){
      yield* _mapFetchOwnMembersEvent(event);
    }
  }
  Stream<FetchOwnChannelMembersState> _mapFetchOwnMembersEvent(
      FetchOwnChannelMembersEvent event) async* {
    String topicName = event.topicName;
    List<MemberVo> list = [];
    final subscribers = await SubscriberRepo().getByTopicExceptNone(topicName) ;

    for (final sub in subscribers) {
      if (sub.chatId.length < 64) {
        NLog.w('chatID is_____' + sub.chatId.toString());
        break;
      }
      if (sub.chatId.contains('__permission__')) {
        NLog.w('chatID is_____' + sub.chatId.toString());
        break;
      }

      final contactType = sub.chatId == NKNClientCaller.currentChatId
          ? ContactType.me
          : ContactType.stranger;
      ContactSchema cta =
          await ContactSchema.fetchContactByAddress(sub.chatId) ??
              ContactSchema(clientAddress: sub.chatId, type: contactType);

      MemberVo member = MemberVo(
        name: cta.getShowName,
        chatId: sub.chatId,
        indexPermiPage: sub.indexPermiPage,
        contact: cta,
        memberStatus: sub.memberStatus,
      );
      list.add(member);
    }
    NLog.w('Got Own subscribers List is____' + list.length.toString());
    yield FetchOwnChannelMembersState(list);
  }

  Stream<FetchChannelMembersState> _mapFetchMembersEvent(
      FetchChannelMembersEvent event) async* {
    String topicName = event.topicName;
    List<MemberVo> list = [];
    final subscribers = await SubscriberRepo().getAllMemberByTopic(topicName);

    for (final sub in subscribers) {
      if (sub.chatId.length < 64) {
        NLog.w('chatID is_____' + sub.chatId.toString());
        break;
      }
      if (sub.chatId.contains('__permission__')){
        NLog.w('chatID is_____' + sub.chatId.toString());
        break;
      }

      final contactType = sub.chatId == NKNClientCaller.currentChatId
          ? ContactType.me
          : ContactType.stranger;
      ContactSchema cta =
          await ContactSchema.fetchContactByAddress(sub.chatId) ??
              ContactSchema(clientAddress: sub.chatId, type: contactType);

      MemberVo member = MemberVo(
        name: cta.getShowName,
        chatId: sub.chatId,
        indexPermiPage: sub.indexPermiPage,
        contact: cta,
        memberStatus: sub.memberStatus,
      );
      list.add(member);
    }
    NLog.w('Got subscribers List is____' + list.length.toString());
    yield FetchChannelMembersState(list);
  }
}

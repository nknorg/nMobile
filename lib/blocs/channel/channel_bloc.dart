import 'package:bloc/bloc.dart';
import 'package:nmobile/blocs/channel/channel_event.dart';
import 'package:nmobile/blocs/channel/channel_state.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/model/datacenter/contact_data_center.dart';
import 'package:nmobile/model/datacenter/group_data_center.dart';
import 'package:nmobile/model/entity/subscriber_repo.dart';
import 'package:nmobile/model/entity/contact.dart';
import 'package:nmobile/model/group_chat_helper.dart';
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
  }

  Stream<FetchChannelMembersState> _mapFetchMembersEvent(
      FetchChannelMembersEvent event) async* {
    String topicName = event.topicName;
    List<MemberVo> list = [];

    List<Subscriber> subscribers = await SubscriberRepo().getAllSubscribedMemberByTopic(topicName);
    if (isPrivateTopicReg(topicName)){
      String owner = getPubkeyFromTopicOrChatId(topicName);
      if (owner == NKNClientCaller.currentChatId){
        subscribers = await SubscriberRepo().getAllMemberWithNoMemberStatus(topicName);
      }
    }

    for (Subscriber sub in subscribers) {
      if (sub.chatId.length < 64 || sub.chatId.contains('__permission__')){
        NLog.w('Wrong!!!database Wrong chatID___'+sub.chatId.toString());
      }
      else{
        ContactSchema contact = await ContactSchema.fetchContactByAddress(sub.chatId);
        if (contact == null && sub.chatId != NKNClientCaller.currentChatId){
          ContactSchema contact = ContactSchema(
              type: ContactType.stranger,
              clientAddress: sub.chatId);
          await contact.insertContact();
        }
        NLog.w('contact.sub.chatId is____'+sub.chatId.toString());

        MemberVo member = MemberVo(
          name: contact.getShowName,
          chatId: sub.chatId,
          indexPermiPage: sub.indexPermiPage,
          contact: contact,
          memberStatus: sub.memberStatus,
        );
        list.add(member);
      }
    }
    NLog.w('Got subscribers List is____' + list.length.toString());
    yield FetchChannelMembersState(list);
  }
}

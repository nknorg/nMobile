import 'package:bloc/bloc.dart';
import 'package:nmobile/blocs/chat/channel_event.dart';
import 'package:nmobile/blocs/chat/channel_state.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/model/data/contact_data_center.dart';
import 'package:nmobile/model/db/black_list_repo.dart';
import 'package:nmobile/model/db/subscriber_repo.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/screens/chat/channel_members.dart';
import 'package:nmobile/utils/nlog_util.dart';

class ChannelBloc extends Bloc<ChannelMembersEvent, ChannelState> {
  @override
  ChannelState get initialState => ChannelUpdateState();

  @override
  Stream<ChannelState> mapEventToState(ChannelMembersEvent event) async* {
    if (event is ChannelMemberCountEvent) {
      String topicName = event.topicName;
      int count = await SubscriberRepo().getCountOfTopic(topicName);

      yield ChannelMembersState(count, topicName);
    } else if (event is FetchChannelMembersEvent) {
      yield* _mapFetchMembersEvent(event);
    }
  }

  Stream<FetchChannelMembersState> _mapFetchMembersEvent(
      FetchChannelMembersEvent event) async* {
    String topicName = event.topicName;
    List<MemberVo> list = [];
    final subscribers = await SubscriberRepo().getByTopicExceptNone(topicName);

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
        uploaded: sub.uploaded,
        subscribed: sub.subscribed,
        isBlack: false,
        contact: cta,
      );
      list.add(member);
    }
    final blackList = await BlackListRepo().getByTopic(topicName);
    for (final sub in blackList) {
      final contactType =
          (sub.chatIdOrPubkey == NKNClientCaller.currentChatId ||
                  sub.chatIdOrPubkey == NKNClientCaller.currentChatId)
              ? ContactType.me
              : ContactType.stranger;
      final cta = await ContactSchema.fetchContactByAddress(
              sub.chatIdOrPubkey) ??
          ContactSchema(clientAddress: sub.chatIdOrPubkey, type: contactType);
      list.add(MemberVo(
        name: cta.getShowName,
        chatId: sub.chatIdOrPubkey,
        indexPermiPage: sub.indexPermiPage,
        uploaded: sub.uploaded,
        subscribed: sub.subscribed,
        isBlack: true,
        contact: cta,
      ));
    }
    NLog.w('Got subscribers List is____' + list.length.toString());
    yield FetchChannelMembersState(list);
  }
}

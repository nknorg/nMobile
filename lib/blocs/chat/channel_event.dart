
abstract class ChannelMembersEvent{
  const ChannelMembersEvent();
}

class ChannelMemberCountEvent extends ChannelMembersEvent {
  final String topicName;
  ChannelMemberCountEvent(this.topicName);
}

class FetchChannelMembersEvent extends ChannelMembersEvent{
  final String topicName;
  FetchChannelMembersEvent(this.topicName);
}
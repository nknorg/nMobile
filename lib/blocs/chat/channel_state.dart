import 'package:nmobile/screens/chat/channel_members.dart';

abstract class ChannelState {
  const ChannelState();
}

class ChannelMembersState extends ChannelState{
  final int memberCount;
  String topicName;

  ChannelMembersState(this.memberCount,this.topicName);
}

class FetchChannelMembersState extends ChannelState{
  final List<MemberVo> memberList;
  const FetchChannelMembersState(this.memberList);
}

class ChannelUpdateState extends ChannelState{

  ChannelUpdateState();
}
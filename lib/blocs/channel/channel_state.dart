import 'package:nmobile/screens/chat/channel_members.dart';

abstract class ChannelState {
  const ChannelState();
}

class ChannelMembersState extends ChannelState {
  final int memberCount;
  String topicName;
  ChannelMembersState(this.memberCount, this.topicName);
}

class ChannelOwnMembersState extends ChannelState {
  final int inviteMemberCount;
  final int joinedMemberCount;
  final int rejectMemberCount;
  String topicName;
  ChannelOwnMembersState(
      this.inviteMemberCount,
      this.joinedMemberCount,
      this.rejectMemberCount,
      this.topicName);
}

class FetchChannelMembersState extends ChannelState {
  final List<MemberVo> memberList;
  const FetchChannelMembersState(this.memberList);
}

class FetchOwnChannelMembersState extends ChannelState{
  final List<MemberVo> memberList;
  const FetchOwnChannelMembersState(this.memberList);
}

class ChannelUpdateState extends ChannelState {
  ChannelUpdateState();
}

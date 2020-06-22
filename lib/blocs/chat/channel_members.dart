import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChannelMembersBloc extends Bloc<ChannelMembersEvent, ChannelMembersState> {
  @override
  ChannelMembersState get initialState => ChannelMembersState(null);

  @override
  Stream<ChannelMembersState> mapEventToState(ChannelMembersEvent event) async* {
    yield ChannelMembersState(event);
  }
}

abstract class ChannelMembersEvent extends Equatable {}

class MembersCount extends ChannelMembersEvent {
  final String topicName;
  final int subscriberCount;
  final bool isFinal;

  MembersCount(this.topicName, this.subscriberCount, this.isFinal);

  @override
  List<Object> get props => [topicName, subscriberCount, isFinal];
}

class ChannelMembersState {
  final MembersCount membersCount;

  ChannelMembersState(this.membersCount);
}

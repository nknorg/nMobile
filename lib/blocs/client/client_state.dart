import 'package:equatable/equatable.dart';
import 'package:nmobile/model/entity/message.dart';

abstract class NKNClientState extends Equatable {
  const NKNClientState();

  @override
  List<Object> get props => [];
}

class NKNNoConnectState extends NKNClientState {}

class NKNConnectingState extends NKNClientState {}

class NKNConnectedState extends NKNClientState {
  final MessageSchema message;

  NKNConnectedState({this.message});
}

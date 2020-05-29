import 'package:equatable/equatable.dart';

abstract class ContactEvent extends Equatable {
  const ContactEvent();

  @override
  List<Object> get props => [];
}

class LoadContact extends ContactEvent {
  final List<String> address;
  const LoadContact({this.address});
}

class RefreshContact extends ContactEvent {
  final int id;
  const RefreshContact({this.id}); 
}

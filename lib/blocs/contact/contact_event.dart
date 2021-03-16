import 'package:equatable/equatable.dart';
import 'package:nmobile/schemas/contact.dart';

abstract class ContactEvent extends Equatable {
  const ContactEvent();

  @override
  List<Object> get props => [];
}

class LoadContact extends ContactEvent {
  final List<String> address;
  const LoadContact({this.address});
}

class LoadContactInfoEvent extends ContactEvent {
  final String address;
  const LoadContactInfoEvent(this.address);
}

class RefreshContact extends ContactEvent {
  final int id;
  const RefreshContact({this.id});
}

class UpdateUserInfoEvent extends ContactEvent {
  final ContactSchema userInfo;
  const UpdateUserInfoEvent(this.userInfo);
}

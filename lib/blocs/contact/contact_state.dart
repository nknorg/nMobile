import 'package:nmobile/schemas/contact.dart';

abstract class ContactState {
  const ContactState();
}

class ContactNotLoad extends ContactState {}

class ContactLoading extends ContactState {}

class ContactLoaded extends ContactState {
  final List<ContactSchema> contacts;
  const ContactLoaded([this.contacts = const []]);

  ContactSchema getContactByAddress(String address) {
    if (contacts == null || contacts.length == 0) {
      return null;
    }
    try {
      return contacts.firstWhere((x) => x.clientAddress == address, orElse: () => null);
    } catch (e) {
      return null;
    }
  }
}

class UpdateUserInfoState extends ContactState{
  final ContactSchema userInfo;
  const UpdateUserInfoState(this.userInfo);
}

class LoadContactInfoState extends ContactState{
  final ContactSchema userInfo;
  const LoadContactInfoState(this.userInfo);
}


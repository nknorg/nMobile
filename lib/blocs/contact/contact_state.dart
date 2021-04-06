import 'package:nmobile/model/entity/contact.dart';
import 'package:nmobile/utils/nlog_util.dart';

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
      NLog.w('getContactByAddress return null___'+address.toString());
      return null;
    }
    try {

      ContactSchema contact = contacts.firstWhere((x) => x.clientAddress == address,
          orElse: () => null);
      if (contact != null){
        return contact;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

class UpdateUserInfoState extends ContactState {
  final ContactSchema userInfo;
  const UpdateUserInfoState(this.userInfo);
}

class LoadContactInfoState extends ContactState {
  final ContactSchema userInfo;
  const LoadContactInfoState(this.userInfo);
}

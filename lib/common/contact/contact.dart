import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/utils/utils.dart';

import '../locator.dart';

class ContactType {
  static const String stranger = 'stranger';
  static const String friend = 'friend';
  static const String me = 'me';
}

class RequestType {
  static const String header = 'header';
  static const String full = 'full';
}

class Contact {
  ContactSchema currentUser;
  ContactStorage _contactStorage = ContactStorage();

  Future<ContactSchema> fetchCurrentUser(String clientAddress) async {
    ContactSchema contact = await _contactStorage.queryContactByClientAddress(clientAddress);
    currentUser = contact;
    return contact;
  }
}
import 'dart:async';

import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/utils/utils.dart';

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

  StreamController<ContactSchema> _addController = StreamController<ContactSchema>.broadcast();
  StreamSink<ContactSchema> get _addSink => _addController.sink;
  Stream<ContactSchema> get addStream => _addController.stream;

  StreamController<ContactSchema> _deleteController = StreamController<ContactSchema>.broadcast();
  StreamSink<ContactSchema> get _deleteSink => _deleteController.sink;
  Stream<ContactSchema> get deleteStream => _deleteController.stream;

  StreamController<List<ContactSchema>> _updateController = StreamController<List<ContactSchema>>.broadcast();
  StreamSink<List<ContactSchema>> get _updateSink => _updateController.sink;
  Stream<List<ContactSchema>> get updateStream => _updateController.stream;

  close() {
    _addController?.close();
    _deleteController?.close();
    _updateController?.close();
  }

  Future<ContactSchema> fetchCurrentUser(String clientAddress) async {
    if (clientAddress == null || clientAddress.isEmpty) return null;
    ContactSchema contact = await _contactStorage.queryContactByClientAddress(clientAddress);
    if (contact != null) {
      if (contact.nknWalletAddress == null || contact.nknWalletAddress.isEmpty) {
        contact.nknWalletAddress = await Wallet.pubKeyToWalletAddr(getPublicKeyByClientAddr(contact.clientAddress));
      }
    }
    currentUser = contact;
    return contact;
  }

  Future<ContactSchema> add(ContactSchema scheme) async {
    if (scheme == null || scheme.clientAddress == null || scheme.clientAddress.isEmpty) return null;

    scheme.nknWalletAddress = await Wallet.pubKeyToWalletAddr(getPublicKeyByClientAddr(scheme.clientAddress));

    ContactSchema added = await _contactStorage.insertContact(scheme);
    if (added != null) {
      _addSink.add(added);
      return added;
    }
    return added;
  }
}

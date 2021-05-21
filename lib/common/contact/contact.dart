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

  StreamController<int> _deleteController = StreamController<int>.broadcast();
  StreamSink<int> get _deleteSink => _deleteController.sink;
  Stream<int> get deleteStream => _deleteController.stream;

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
    if (added != null) _addSink.add(added);
    return added;
  }

  Future<bool> delete(int contactId) async {
    if (contactId == null || contactId == 0) return false;
    bool deleted = await _contactStorage.deleteContact(contactId);
    if (deleted) _deleteSink.add(contactId);
    return deleted;
  }

  Future<List<ContactSchema>> queryContacts({String contactType, String orderBy, int limit, int offset}) {
    return _contactStorage.queryContacts(contactType: contactType, orderBy: orderBy, limit: limit, offset: offset);
  }

  Future<ContactSchema> queryContact(int contactId) {
    if (contactId == null || contactId == 0) return null;
    return _contactStorage.queryContact(contactId);
  }

  Future<ContactSchema> queryContactByClientAddress(String clientAddress) {
    if (clientAddress == null || clientAddress.isEmpty) return null;
    return _contactStorage.queryContactByClientAddress(clientAddress);
  }

  Future<int> queryCountByClientAddress(String clientAddress) {
    if (clientAddress == null || clientAddress.isEmpty) return Future.value(0);
    return _contactStorage.queryCountByClientAddress(clientAddress);
  }

  Future<bool> setType(int contactId, String contactType, {bool notify = false}) async {
    if (contactType == null || contactType == ContactType.me) return false;
    bool success = await _contactStorage.setType(contactId, contactType);
    if (success && notify) queryAndNotify(contactId);
    return success;
  }

  Future<bool> setName(ContactSchema schema, String name, {bool notify = false}) async {
    if (schema == null || schema.id == 0 || name == null || name.isEmpty) return false;
    bool success = await _contactStorage.setProfile(
      schema.id,
      {'first_name': name},
      oldProfileInfo: (schema.firstName == null || schema.firstName.isEmpty) ? null : {'first_name': schema.firstName},
    );
    if (success && notify) queryAndNotify(schema.id);
    return success;
  }

  Future<bool> setAvatar(ContactSchema schema, String avatarLocalPath, {bool notify = false}) async {
    if (schema == null || schema.id == 0 || avatarLocalPath == null || avatarLocalPath.isEmpty) return false;
    bool success = await _contactStorage.setProfile(
      schema.id,
      {'avatar': avatarLocalPath},
      oldProfileInfo: (schema.avatar == null || schema.avatar.isEmpty) ? null : {'avatar': schema.avatar},
    );
    if (success && notify) queryAndNotify(schema.id);
    return success;
  }

  Future<bool> setProfileVersion(int contactId, String profileVersion, {bool notify = false}) async {
    if (contactId == null || contactId == 0 || profileVersion == null) return false;
    bool success = await _contactStorage.setProfileVersion(contactId, profileVersion);
    if (success && notify) queryAndNotify(contactId);
    return success;
  }

  Future<bool> setProfileExpiresAt(int contactId, int expiresAt, {bool notify = false}) async {
    if (contactId == null || contactId == 0 || expiresAt == null) return false;
    bool success = await _contactStorage.setProfileExpiresAt(contactId, expiresAt);
    if (success && notify) queryAndNotify(contactId);
    return success;
  }

  Future<bool> setRemarkName(ContactSchema schema, String name, {bool notify = false}) async {
    if (schema == null || schema.id == 0) return false;
    bool success = await _contactStorage.setRemarkProfile(
      schema.id,
      {'first_name': name},
      oldExtraInfo: schema.extraInfo,
    );
    if (success && notify) queryAndNotify(schema.id);
    return success;
  }

  Future<bool> setRemarkAvatar(ContactSchema schema, String avatarLocalPath, {bool notify = false}) async {
    if (schema == null || schema.id == 0) return Future.value(false);
    bool success = await _contactStorage.setRemarkProfile(
      schema.id,
      {'remark_avatar': avatarLocalPath},
      oldExtraInfo: schema.extraInfo,
    );
    if (success && notify) queryAndNotify(schema.id);
    return success;
  }

  // TODO:GG setOrUpdateExtraProfile need??

  Future<bool> setNotes(ContactSchema schema, String notes, {bool notify = false}) async {
    if (schema == null || schema.id == null || schema.id == 0) return null;
    bool success = await _contactStorage.setNotes(schema.id, notes, oldExtraInfo: schema.extraInfo);
    if (success && notify) queryAndNotify(schema.id);
    return success;
  }

  Future<bool> toggleOptionsColors(ContactSchema schema, {bool notify = false}) async {
    if (schema == null || schema.id == null || schema.id == 0) return false;
    bool success = await _contactStorage.setOptionsColors(schema.id, old: schema.options);
    if (success && notify) queryAndNotify(schema.id);
    return success;
  }

  Future<bool> setOptionsBurn(ContactSchema schema, int seconds, {bool notify = false}) async {
    if (schema == null || schema.id == null || schema.id == 0) return false;
    bool success = await _contactStorage.setOptionsBurn(schema.id, seconds, old: schema.options);
    if (success && notify) queryAndNotify(schema.id);
    return success;
  }

  Future<bool> setTop(String clientAddress, bool top, {bool notify = false}) async {
    if (clientAddress == null || clientAddress.isEmpty) return false;
    bool success = await _contactStorage.setTop(clientAddress, top);
    if (success && notify) queryAndNotifyVyClientAddress(clientAddress);
    return success;
  }

  Future<bool> isTop(String clientAddress) {
    if (clientAddress == null || clientAddress.isEmpty) return Future.value(false);
    return _contactStorage.isTop(clientAddress);
  }

  Future<bool> setDeviceToken(int contactId, String deviceToken, {bool notify = false}) async {
    if (contactId == null || contactId == 0 || deviceToken == null || deviceToken.isEmpty) return false;
    bool success = await _contactStorage.setDeviceToken(contactId, deviceToken);
    if (success && notify) queryAndNotify(contactId);
    return success;
  }

  Future<bool> setNotificationOpen(int contactId, bool open, {bool notify = false}) async {
    if (contactId == null || contactId == 0 || open == null) return false;
    bool success = await _contactStorage.setNotificationOpen(contactId, open);
    if (success && notify) queryAndNotify(contactId);
    return success;
  }

  queryAndNotify(int contactId) async {
    ContactSchema updated = await _contactStorage.queryContact(contactId);
    _updateSink.add([updated]);
  }

  queryAndNotifyVyClientAddress(String clientAddress) async {
    ContactSchema updated = await _contactStorage.queryContactByClientAddress(clientAddress);
    _updateSink.add([updated]);
  }
}

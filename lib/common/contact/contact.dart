import 'dart:async';

import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/utils.dart';
import 'package:uuid/uuid.dart';

class ContactCommon with Tag {
  ContactStorage _contactStorage = ContactStorage();

  StreamController<ContactSchema> _addController = StreamController<ContactSchema>.broadcast();
  StreamSink<ContactSchema> get _addSink => _addController.sink;
  Stream<ContactSchema> get addStream => _addController.stream;

  // StreamController<int> _deleteController = StreamController<int>.broadcast();
  // StreamSink<int> get _deleteSink => _deleteController.sink;
  // Stream<int> get deleteStream => _deleteController.stream;

  StreamController<ContactSchema> _updateController = StreamController<ContactSchema>.broadcast();
  StreamSink<ContactSchema> get _updateSink => _updateController.sink;
  Stream<ContactSchema> get updateStream => _updateController.stream;

  StreamController<ContactSchema?> _meUpdateController = StreamController<ContactSchema?>.broadcast();
  StreamSink<ContactSchema?> get meUpdateSink => _meUpdateController.sink;
  Stream<ContactSchema?> get meUpdateStream => _meUpdateController.stream;

  ContactCommon();

  close() {
    _addController.close();
    // _deleteController.close();
    _updateController.close();
    _meUpdateController.close();
  }

  Future<ContactSchema?> getMe({String? clientAddress, bool canAdd = false}) async {
    List<ContactSchema> contacts = await _contactStorage.queryList(contactType: ContactType.me, limit: 1);
    ContactSchema? contact = contacts.isNotEmpty ? contacts[0] : await _contactStorage.queryByClientAddress(clientAddress ?? clientCommon.address);
    if (contact == null && canAdd) {
      contact = await addByType(clientAddress ?? clientCommon.address, ContactType.me, notify: true, checkDuplicated: false);
    }
    if (contact != null) {
      if (contact.nknWalletAddress == null || contact.nknWalletAddress!.isEmpty) {
        try {
          contact.nknWalletAddress = await Wallet.pubKeyToWalletAddr(getPublicKeyByClientAddr(contact.clientAddress));
        } catch (e) {
          handleError(e);
        }
      }
    }
    return contact;
  }

  Future<ContactSchema?> addByType(String? clientAddress, int contactType, {bool notify = false, bool checkDuplicated = true}) async {
    if (clientAddress == null || clientAddress.isEmpty) return null;
    ContactSchema? schema = await ContactSchema.createByType(clientAddress, type: contactType);
    return add(schema, notify: notify, checkDuplicated: checkDuplicated);
  }

  Future<ContactSchema?> add(ContactSchema? schema, {bool notify = false, bool checkDuplicated = true}) async {
    if (schema == null || schema.clientAddress.isEmpty) return null;
    if (schema.nknWalletAddress == null || schema.nknWalletAddress!.isEmpty) {
      try {
        schema.nknWalletAddress = await Wallet.pubKeyToWalletAddr(getPublicKeyByClientAddr(schema.clientAddress));
      } catch (e) {
        handleError(e);
      }
    }
    if (checkDuplicated) {
      ContactSchema? exist = await queryByClientAddress(schema.clientAddress);
      if (exist != null) {
        logger.i("$TAG - add - duplicated - schema:$exist");
        return null;
      }
    }
    ContactSchema? added = await _contactStorage.insert(schema);
    if (added != null && notify) _addSink.add(added);
    return added;
  }

  Future<bool> delete(int? contactId, {bool notify = false}) async {
    if (contactId == null || contactId == 0) return false;
    // bool success = await _contactStorage.delete(contactId);
    // if (success) _deleteSink.add(contactId);
    // return success;
    bool success = await _contactStorage.setType(contactId, ContactType.none);
    if (success && notify) queryAndNotify(contactId);
    return success;
  }

  Future<ContactSchema?> query(int? contactId) async {
    if (contactId == null || contactId == 0) return null;
    return await _contactStorage.query(contactId);
  }

  Future<ContactSchema?> queryByClientAddress(String? clientAddress) async {
    if (clientAddress == null || clientAddress.isEmpty) return null;
    return await _contactStorage.queryByClientAddress(clientAddress);
  }

  Future<List<ContactSchema>> queryList({int? contactType, String? orderBy, int? offset, int? limit}) {
    return _contactStorage.queryList(contactType: contactType, orderBy: orderBy, offset: offset, limit: limit);
  }

  Future<bool> setType(int? contactId, int? contactType, {bool notify = false}) async {
    if (contactId == null || contactId == 0 || contactType == null || contactType == ContactType.me) return false;
    bool success = await _contactStorage.setType(contactId, contactType);
    if (success && notify) queryAndNotify(contactId);
    return success;
  }

  Future<bool> setSelfAvatar(ContactSchema? old, String avatarLocalPath, {bool notify = false}) async {
    if (old == null || old.id == 0) return false;
    bool success = await _contactStorage.setProfile(
      old.id,
      {
        'avatar': avatarLocalPath,
        'first_name': old.firstName,
        'last_name': old.lastName,
        'profile_version': Uuid().v4(),
        'profile_expires_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
    if (success && notify) queryAndNotify(old.id);
    return success;
  }

  Future<bool> setSelfName(ContactSchema? old, String firstName, String lastName, {bool notify = false}) async {
    if (old == null || old.id == 0) return false;
    bool success = await _contactStorage.setProfile(
      old.id,
      {
        'avatar': Path.getLocalFile(old.avatar?.path),
        'first_name': firstName,
        'last_name': lastName,
        'profile_version': Uuid().v4(),
        'profile_expires_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
    if (success && notify) queryAndNotify(old.id);
    return success;
  }

  Future<bool> setOtherProfile(ContactSchema? old, String? firstName, String? lastName, String? avatarLocalPath, String? profileVersion, {bool notify = false}) async {
    if (old == null || old.id == 0) return false; //  || name == null || name.isEmpty || avatarLocalPath == null || avatarLocalPath.isEmpty
    bool success = await _contactStorage.setProfile(
      old.id,
      {
        'avatar': avatarLocalPath,
        'first_name': firstName,
        'last_name': lastName,
        'profile_version': profileVersion ?? Uuid().v4(),
        'profile_expires_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
    if (success && notify) queryAndNotify(old.id);
    return success;
  }

  Future<bool> setTop(String? clientAddress, bool top, {bool notify = false}) async {
    if (clientAddress == null || clientAddress.isEmpty) return false;
    bool success = await _contactStorage.setTop(clientAddress, top);
    if (success && notify) queryAndNotifyByClientAddress(clientAddress);
    return success;
  }

  Future<bool> setDeviceToken(int? contactId, String? deviceToken, {bool notify = false}) async {
    if (contactId == null || contactId == 0) return false;
    bool success = await _contactStorage.setDeviceToken(contactId, deviceToken);
    if (success && notify) queryAndNotify(contactId);
    return success;
  }

  Future<bool> setNotificationOpen(ContactSchema? schema, bool open, {bool notify = false}) async {
    if (schema == null || schema.id == null || schema.id == 0) return false;
    bool success = await _contactStorage.setNotificationOpen(schema.id, open, old: schema.options);
    if (success && notify) queryAndNotify(schema.id);
    return success;
  }

  Future<bool> setOptionsBurn(ContactSchema? schema, int? burningSeconds, int? updateAt, {bool notify = false}) async {
    if (schema == null || schema.id == null || schema.id == 0) return false;
    bool success = await _contactStorage.setBurning(schema.id, burningSeconds, updateAt, old: schema.options);
    if (success && notify) queryAndNotify(schema.id);
    return success;
  }

  Future<bool> setRemarkAvatar(ContactSchema? old, String avatarLocalPath, {bool notify = false}) async {
    if (old == null || old.id == 0) return Future.value(false);
    bool success = await _contactStorage.setRemarkProfile(
      old.id,
      {
        'firstName': old.data?['firstName'],
        'lasName': old.data?['lasName'],
        'avatar': avatarLocalPath,
      },
    );
    if (success && notify) queryAndNotify(old.id);
    return success;
  }

  Future<bool> setRemarkName(ContactSchema? old, String firstName, String lastName, {bool notify = false}) async {
    if (old == null || old.id == 0) return false;
    bool success = await _contactStorage.setRemarkProfile(
      old.id,
      {
        'firstName': firstName,
        'lasName': lastName,
        'avatar': old.data?['avatar'],
      },
    );
    if (success && notify) queryAndNotify(old.id);
    return success;
  }

  Future<bool> setNotes(ContactSchema? schema, String? notes, {bool notify = false}) async {
    if (schema == null || schema.id == null || schema.id == 0) return false;
    bool success = await _contactStorage.setNotes(schema.id, notes, oldExtraInfo: schema.data);
    if (success && notify) queryAndNotify(schema.id);
    return success;
  }

  Future queryAndNotify(int? contactId) async {
    if (contactId == null || contactId == 0) return;
    ContactSchema? updated = await _contactStorage.query(contactId);
    if (updated != null) {
      _updateSink.add(updated);
      if (updated.type == ContactType.me) {
        meUpdateSink.add(updated);
      }
    }
  }

  Future queryAndNotifyByClientAddress(String? clientAddress) async {
    if (clientAddress == null || clientAddress.isEmpty) return;
    ContactSchema? updated = await queryByClientAddress(clientAddress);
    if (updated != null) {
      _updateSink.add(updated);
      if (updated.type == ContactType.me) {
        meUpdateSink.add(updated);
      }
    }
  }

  bool isProfileVersionSame(String? v1, String? v2) {
    return v1 != null && v1.isNotEmpty && v1 == v2;
  }
}

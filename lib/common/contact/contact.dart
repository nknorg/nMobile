import 'dart:async';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/name_service/resolver.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/validate.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:uuid/uuid.dart';

class ContactCommon with Tag {
  // ignore: close_sinks
  StreamController<ContactSchema> _addController = StreamController<ContactSchema>.broadcast();
  StreamSink<ContactSchema> get _addSink => _addController.sink;
  Stream<ContactSchema> get addStream => _addController.stream;

  // ignore: close_sinks
  // StreamController<int> _deleteController = StreamController<int>.broadcast();
  // StreamSink<int> get _deleteSink => _deleteController.sink;
  // Stream<int> get deleteStream => _deleteController.stream;

  // ignore: close_sinks
  StreamController<ContactSchema> _updateController = StreamController<ContactSchema>.broadcast();
  StreamSink<ContactSchema> get _updateSink => _updateController.sink;
  Stream<ContactSchema> get updateStream => _updateController.stream;

  // ignore: close_sinks
  StreamController<ContactSchema?> _meUpdateController = StreamController<ContactSchema?>.broadcast();
  StreamSink<ContactSchema?> get meUpdateSink => _meUpdateController.sink;
  Stream<ContactSchema?> get meUpdateStream => _meUpdateController.stream;

  ContactCommon();

  Future<String?> resolveClientAddress(String? address) async {
    if ((address == null) || address.isEmpty) return null;
    String? clientAddress;
    try {
      Resolver resolver = Resolver();
      clientAddress = await resolver.resolve(address);
    } catch (e, st) {
      handleError(e, st);
    }
    if ((clientAddress != null) && Validate.isNknChatIdentifierOk(clientAddress)) {
      return clientAddress;
    } else {
      if (Validate.isNknChatIdentifierOk(address)) {
        return address;
      } else {
        return null;
      }
    }
  }

  Future<ContactSchema?> resolveByAddress(String? address, {bool canAdd = false}) async {
    if ((address == null) || address.isEmpty) return null;
    // address
    String? clientAddress;
    try {
      Resolver resolver = Resolver();
      clientAddress = await resolver.resolve(address);
    } catch (e, st) {
      handleError(e, st);
    }
    bool resolveOk = false;
    if ((clientAddress != null) && Validate.isNknChatIdentifierOk(clientAddress)) {
      resolveOk = true;
    } else {
      if (Validate.isNknChatIdentifierOk(address)) {
        clientAddress = address;
      } else {
        return null;
      }
    }
    // query
    ContactSchema? contact = await queryByClientAddress(clientAddress);
    // add
    if (canAdd) {
      if (contact != null) {
        if (contact.type == ContactType.none) {
          bool success = await setType(contact.id, ContactType.stranger, notify: true);
          if (success) contact.type = ContactType.stranger;
        }
      } else {
        contact = await addByType(clientAddress, ContactType.stranger, notify: true, checkDuplicated: false);
      }
    }
    if ((contact != null) && resolveOk) {
      if (!contact.mappedAddress.contains(address)) {
        List<String> added = contact.mappedAddress..add(address);
        await setMappedAddress(contact, added.toSet().toList(), notify: true);
      }
    }
    return contact;
  }

  Future<ContactSchema?> getMe({String? clientAddress, bool canAdd = false, bool needWallet = false}) async {
    List<ContactSchema> contacts = await ContactStorage.instance.queryList(contactType: ContactType.me, limit: 1);
    ContactSchema? contact = contacts.isNotEmpty ? contacts[0] : null;
    String myAddress = clientAddress ?? clientCommon.address ?? "";
    if ((contact == null) && myAddress.isNotEmpty) {
      contact = await ContactStorage.instance.queryByClientAddress(myAddress);
    }
    if ((contact == null) && myAddress.isNotEmpty && canAdd) {
      contact = await addByType(myAddress, ContactType.me, notify: true, checkDuplicated: false);
    }
    if (contact == null) return null;
    if ((contact.profileVersion == null) || (contact.profileVersion?.isEmpty == true)) {
      String profileVersion = Uuid().v4();
      bool success = await setProfileVersion(contact, profileVersion);
      if (success) contact.profileVersion = profileVersion;
    }
    if (needWallet) {
      if ((contact.nknWalletAddress == null) || (contact.nknWalletAddress?.isEmpty == true)) {
        String? nknWalletAddress = await contact.tryNknWalletAddress();
        bool success = await setWalletAddress(contact, nknWalletAddress);
        if (success) contact.nknWalletAddress = nknWalletAddress;
      }
    }
    return contact;
  }

  Future<ContactSchema?> addByType(String? clientAddress, int contactType, {bool notify = false, bool checkDuplicated = true}) async {
    if (clientAddress == null || clientAddress.isEmpty) return null;
    ContactSchema? schema = await ContactSchema.create(clientAddress, contactType);
    return add(schema, notify: notify, checkDuplicated: checkDuplicated);
  }

  Future<ContactSchema?> add(ContactSchema? schema, {bool notify = false, bool checkDuplicated = true}) async {
    if (schema == null || schema.clientAddress.isEmpty) return null;
    if (checkDuplicated) {
      ContactSchema? exist = await queryByClientAddress(schema.clientAddress);
      if (exist != null) {
        logger.d("$TAG - add - duplicated - schema:$exist");
        return null;
      }
    }
    schema.nknWalletAddress = await schema.tryNknWalletAddress();
    ContactSchema? added = await ContactStorage.instance.insert(schema);
    if (added != null && notify) _addSink.add(added);
    return added;
  }

  Future<bool> delete(int? contactId, {bool notify = false}) async {
    if (contactId == null || contactId == 0) return false;
    // bool success = await ContactStorage.instance.delete(contactId);
    // if (success) _deleteSink.add(contactId);
    // return success;
    bool success = await ContactStorage.instance.setType(contactId, ContactType.none);
    if (success && notify) queryAndNotify(contactId);
    return success;
  }

  Future<ContactSchema?> query(int? contactId) async {
    if (contactId == null || contactId == 0) return null;
    return await ContactStorage.instance.query(contactId);
  }

  Future<ContactSchema?> queryByClientAddress(String? clientAddress) async {
    if (clientAddress == null || clientAddress.isEmpty) return null;
    ContactSchema? _schema = await ContactStorage.instance.queryByClientAddress(clientAddress);
    if ((_schema != null) && ((_schema.nknWalletAddress == null) || (_schema.nknWalletAddress?.isEmpty == true))) {
      String? nknWalletAddress = await _schema.tryNknWalletAddress();
      bool success = await setWalletAddress(_schema, nknWalletAddress);
      if (success) _schema.nknWalletAddress = nknWalletAddress;
    }
    return _schema;
  }

  Future<List<ContactSchema>> queryListByClientAddress(List<String>? clientAddressList) async {
    if (clientAddressList == null || clientAddressList.isEmpty) return [];
    return await ContactStorage.instance.queryListByClientAddress(clientAddressList);
  }

  Future<List<ContactSchema>> queryList({int? contactType, String? orderBy, int offset = 0, int limit = 20}) {
    return ContactStorage.instance.queryList(contactType: contactType, orderBy: orderBy, offset: offset, limit: limit);
  }

  Future<bool> setType(int? contactId, int? contactType, {bool notify = false}) async {
    if (contactId == null || contactId == 0 || contactType == null || contactType == ContactType.me) return false;
    bool success = await ContactStorage.instance.setType(contactId, contactType);
    if (success && notify) queryAndNotify(contactId);
    return success;
  }

  Future<bool> setSelfAvatar(ContactSchema? old, String? avatarLocalPath, {bool notify = false}) async {
    if (old == null || old.id == 0) return false;
    bool success = await ContactStorage.instance.setProfile(
      old.id,
      Uuid().v4(),
      avatarLocalPath,
      old.firstName,
      old.lastName,
    );
    if (success && notify) queryAndNotify(old.id);
    return success;
  }

  Future<bool> setSelfName(ContactSchema? old, String? firstName, String? lastName, {bool notify = false}) async {
    if (old == null || old.id == 0) return false;
    bool success = await ContactStorage.instance.setProfile(
      old.id,
      Uuid().v4(),
      Path.convert2Local(old.avatar?.path),
      firstName,
      lastName,
    );
    if (success && notify) queryAndNotify(old.id);
    return success;
  }

  Future<bool> setOtherProfile(ContactSchema? old, String? profileVersion, String? avatarLocalPath, String? firstName, String? lastName, {bool notify = false}) async {
    if (old == null || old.id == 0) return false;
    bool success = await ContactStorage.instance.setProfile(
      old.id,
      profileVersion,
      avatarLocalPath,
      firstName,
      lastName,
    );
    if (success && notify) queryAndNotify(old.id);
    return success;
  }

  Future<bool> setProfileVersion(ContactSchema? old, String? profileVersion, {bool notify = false}) async {
    if (old == null || old.id == 0) return false;
    bool success = await ContactStorage.instance.setProfileVersion(old.id, profileVersion);
    if (success && notify) queryAndNotify(old.id);
    return success;
  }

  Future<bool> setTop(String? clientAddress, bool top, {bool notify = false}) async {
    if (clientAddress == null || clientAddress.isEmpty) return false;
    bool success = await ContactStorage.instance.setTop(clientAddress, top);
    if (success && notify) queryAndNotifyByClientAddress(clientAddress);
    return success;
  }

  Future<bool> setNotificationOpen(ContactSchema? schema, bool open, {bool notify = false}) async {
    if (schema == null || schema.id == null || schema.id == 0) return false;
    bool success = await ContactStorage.instance.setNotificationOpen(schema.id, open, old: schema.options);
    if (success && notify) queryAndNotify(schema.id);
    return success;
  }

  Future<bool> setOptionsBurn(ContactSchema? schema, int? burningSeconds, int? updateAt, {bool notify = false}) async {
    if (schema == null || schema.id == null || schema.id == 0) return false;
    bool success = await ContactStorage.instance.setBurning(schema.id, burningSeconds, updateAt, old: schema.options);
    if (success && notify) queryAndNotify(schema.id);
    return success;
  }

  Future<bool> setRemarkAvatar(ContactSchema? schema, String? avatarLocalPath, {bool notify = false}) async {
    if (schema == null || schema.id == 0) return Future.value(false);
    String? oldRemarkName = schema.data?['firstName'];
    schema.data?['firstName'] = null; // clear history error
    bool success = await ContactStorage.instance.setRemarkProfile(
      schema.id,
      avatarLocalPath,
      schema.data?['remarkName'] ?? oldRemarkName,
      oldExtraInfo: schema.data,
    );
    if (success && notify) queryAndNotify(schema.id);
    return success;
  }

  Future<bool> setRemarkName(ContactSchema? schema, String? remarkName, {bool notify = false}) async {
    if (schema == null || schema.id == 0) return false;
    String? oldRemarkAvatar = schema.data?['avatar'];
    schema.data?['avatar'] = null; // clear history error
    bool success = await ContactStorage.instance.setRemarkProfile(
      schema.id,
      schema.data?['remarkAvatar'] ?? oldRemarkAvatar,
      remarkName,
      oldExtraInfo: schema.data,
    );
    if (success && notify) queryAndNotify(schema.id);
    return success;
  }

  Future<bool> setNotes(ContactSchema? schema, String? notes, {bool notify = false}) async {
    if (schema == null || schema.id == null || schema.id == 0) return false;
    bool success = await ContactStorage.instance.setNotes(schema.id, notes, oldExtraInfo: schema.data);
    if (success && notify) queryAndNotify(schema.id);
    return success;
  }

  Future<bool> setWalletAddress(ContactSchema? schema, String? walletAddress, {bool notify = false}) async {
    if (schema == null || schema.id == null || schema.id == 0) return false;
    bool success = await ContactStorage.instance.setWalletAddress(schema.id, walletAddress, oldExtraInfo: schema.data);
    if (success && notify) queryAndNotify(schema.id);
    return success;
  }

  Future<bool> setMappedAddress(ContactSchema? schema, List<String>? mapped, {bool notify = false}) async {
    if (schema == null || schema.id == null || schema.id == 0) return false;
    bool success = await ContactStorage.instance.setMappedAddress(schema.id, mapped, oldExtraInfo: schema.data);
    if (success && notify) queryAndNotify(schema.id);
    return success;
  }

  Future queryAndNotify(int? contactId) async {
    if (contactId == null || contactId == 0) return;
    ContactSchema? updated = await ContactStorage.instance.query(contactId);
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

import 'dart:async';

import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/push/device_token.dart';
import 'package:nmobile/common/settings.dart';
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

  Future<ContactSchema?> getMe({String? clientAddress, bool canAdd = false, bool needWallet = false, bool fetchDeviceToken = false}) async {
    List<ContactSchema> contacts = await ContactStorage.instance.queryList(contactType: ContactType.me, limit: 1);
    ContactSchema? contact = contacts.isNotEmpty ? contacts[0] : await ContactStorage.instance.queryByClientAddress(clientAddress ?? clientCommon.address);
    if ((contact == null) && canAdd) {
      contact = await addByType(clientAddress ?? clientCommon.address, ContactType.me, notify: true, checkDuplicated: false);
    }
    if (contact == null) return null;
    if ((contact.profileVersion == null) || (contact.profileVersion?.isEmpty == true)) {
      String profileVersion = Uuid().v4();
      bool success = await setProfileVersion(contact, profileVersion);
      if (success) contact.profileVersion = profileVersion;
    }
    if (needWallet) {
      contact.nknWalletAddress = await contact.tryNknWalletAddress();
    }
    if (fetchDeviceToken) {
      DeviceToken.get(platform: PlatformName.get(), appVersion: int.tryParse(Global.build)).then((deviceToken) {
        if ((contact?.deviceToken != deviceToken) && (deviceToken?.isNotEmpty == true)) {
          setDeviceToken(contact?.id, deviceToken, notify: true); // await
        }
      }); // await
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
    schema.nknWalletAddress = await schema.tryNknWalletAddress();
    if (checkDuplicated) {
      ContactSchema? exist = await queryByClientAddress(schema.clientAddress);
      if (exist != null) {
        logger.d("$TAG - add - duplicated - schema:$exist");
        return null;
      }
    }
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
    return await ContactStorage.instance.queryByClientAddress(clientAddress);
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
      {'avatar': avatarLocalPath, 'first_name': old.firstName, 'last_name': old.lastName},
    );
    if (success && notify) queryAndNotify(old.id);
    return success;
  }

  Future<bool> setSelfName(ContactSchema? old, String? firstName, String? lastName, {bool notify = false}) async {
    if (old == null || old.id == 0) return false;
    bool success = await ContactStorage.instance.setProfile(
      old.id,
      Uuid().v4(),
      {'avatar': Path.convert2Local(old.avatar?.path), 'first_name': firstName, 'last_name': lastName},
    );
    if (success && notify) queryAndNotify(old.id);
    return success;
  }

  Future<bool> setOtherProfile(ContactSchema? old, String? profileVersion, String? avatarLocalPath, String? firstName, String? lastName, {bool notify = false}) async {
    if (old == null || old.id == 0) return false;
    bool success = await ContactStorage.instance.setProfile(
      old.id,
      profileVersion,
      {'avatar': avatarLocalPath, 'first_name': firstName, 'last_name': lastName},
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

  Future<bool> setDeviceToken(int? contactId, String? deviceToken, {bool notify = false}) async {
    if (contactId == null || contactId == 0) return false;
    bool success = await ContactStorage.instance.setDeviceToken(contactId, deviceToken);
    if (success && notify) queryAndNotify(contactId);
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

  Future<bool> setRemarkAvatar(ContactSchema? old, String? avatarLocalPath, {bool notify = false}) async {
    if (old == null || old.id == 0) return Future.value(false);
    bool success = await ContactStorage.instance.setRemarkProfile(
      old.id,
      {'avatar': avatarLocalPath, 'firstName': old.data?['firstName'], 'lasName': old.data?['lasName']},
    );
    if (success && notify) queryAndNotify(old.id);
    return success;
  }

  Future<bool> setRemarkName(ContactSchema? old, String? firstName, String? lastName, {bool notify = false}) async {
    if (old == null || old.id == 0) return false;
    bool success = await ContactStorage.instance.setRemarkProfile(
      old.id,
      {'avatar': old.data?['avatar'], 'firstName': firstName, 'lasName': lastName},
    );
    if (success && notify) queryAndNotify(old.id);
    return success;
  }

  Future<bool> setNotes(ContactSchema? schema, String? notes, {bool notify = false}) async {
    if (schema == null || schema.id == null || schema.id == 0) return false;
    bool success = await ContactStorage.instance.setNotes(schema.id, notes, oldExtraInfo: schema.data);
    if (success && notify) queryAndNotify(schema.id);
    return success;
  }

  Future<bool> setMappedAddress(ContactSchema? schema, List<String> mapped, {bool notify = false}) async {
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

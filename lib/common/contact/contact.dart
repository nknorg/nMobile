import 'dart:async';

import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/name_service/resolver.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/validate.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/schema/option.dart';
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
    ContactSchema? contact = await query(clientAddress);
    // add
    if (canAdd) {
      if (contact != null) {
        if (contact.type == ContactType.none) {
          bool success = await setType(clientAddress, ContactType.stranger, notify: true);
          if (success) contact.type = ContactType.stranger;
        }
      } else {
        contact = await addByType(clientAddress, ContactType.stranger, notify: true);
      }
    }
    // mappedAddress
    if ((contact != null) && resolveOk) {
      if (!contact.mappedAddress.contains(address)) {
        List<String> added = contact.mappedAddress..add(address);
        var data = await setMappedAddress(contact.address, added.toSet().toList(), notify: true);
        if (data != null) contact.data = data;
      }
    }
    return contact;
  }

  Future<ContactSchema?> getMe({
    String? selfAddress,
    bool canAdd = false,
    bool fetchWalletAddress = false,
  }) async {
    List<ContactSchema> contacts = await queryList(type: ContactType.me, orderDesc: false, limit: 1);
    ContactSchema? contact = contacts.isNotEmpty ? contacts[0] : null;
    String myAddress = selfAddress ?? clientCommon.address ?? "";
    if ((contact == null) && myAddress.isNotEmpty) {
      contact = await ContactStorage.instance.query(myAddress);
    }
    if ((contact == null) && myAddress.isNotEmpty && canAdd) {
      contact = await addByType(myAddress, ContactType.me, notify: true);
    }
    if (contact == null) return null;
    if ((contact.profileVersion == null) || (contact.profileVersion?.isEmpty == true)) {
      String profileVersion = Uuid().v4();
      var data = await setProfileVersion(contact.address, profileVersion);
      logger.i("$TAG - getMe - self profileVersion created - profileVersion:$profileVersion - data:$data");
      if (data != null) contact.data = data;
    }
    if (fetchWalletAddress) {
      String nknWalletAddress = contact.data?['nknWalletAddress']?.toString() ?? "";
      if (nknWalletAddress.isEmpty) {
        String nknWalletAddress = await contact.nknWalletAddress;
        var data = await setWalletAddress(contact.address, nknWalletAddress);
        logger.i("$TAG - getMe - self nknWalletAddress create - nknWalletAddress:$nknWalletAddress - data:$data");
        if (data != null) contact.data = data;
      }
    }
    logger.d("$TAG - getMe - fetchWalletAddress:$fetchWalletAddress - contact:$contact");
    return contact;
  }

  Future<ContactSchema?> addByType(String? clientAddress, int type, {bool fetchWalletAddress = true, bool notify = false}) async {
    if (clientAddress == null || clientAddress.isEmpty) return null;
    ContactSchema? schema = ContactSchema.create(clientAddress, type);
    return await add(schema, fetchWalletAddress: fetchWalletAddress, notify: notify);
  }

  Future<ContactSchema?> add(ContactSchema? schema, {bool fetchWalletAddress = true, bool notify = false}) async {
    if (schema == null || schema.address.isEmpty) return null;
    if (fetchWalletAddress) await schema.nknWalletAddress;
    logger.d("$TAG - add - schema:$schema");
    ContactSchema? added = await ContactStorage.instance.insert(schema);
    if ((added != null) && notify) _addSink.add(added);
    return added;
  }

  // Future<bool> delete(int? contactId, {bool notify = false}) async {
  //   if (contactId == null || contactId == 0) return false;
  //   bool success = await ContactStorage.instance.delete(contactId);
  //   if (success) _deleteSink.add(contactId);
  //   return success;
  // }

  Future<ContactSchema?> query(String? address, {bool fetchWalletAddress = true}) async {
    if (address == null || address.isEmpty) return null;
    ContactSchema? _schema = await ContactStorage.instance.query(address);
    if ((_schema != null) && fetchWalletAddress) {
      String nknWalletAddress = _schema.data?['nknWalletAddress']?.toString() ?? "";
      if (nknWalletAddress.isEmpty) {
        nknWalletAddress = await _schema.nknWalletAddress;
        logger.i("$TAG - query - nknWalletAddress:$nknWalletAddress");
        var data = await setWalletAddress(address, nknWalletAddress);
        if (data != null) _schema.data = data;
      }
    }
    return _schema;
  }

  Future<List<ContactSchema>> queryListByAddress(List<String>? clientAddressList) async {
    if (clientAddressList == null || clientAddressList.isEmpty) return [];
    return await ContactStorage.instance.queryListByAddress(clientAddressList);
  }

  Future<List<ContactSchema>> queryList({int? type, bool orderDesc = true, int offset = 0, int limit = 20}) {
    return ContactStorage.instance.queryList(type: type, orderDesc: orderDesc, offset: offset, limit: limit);
  }

  Future<String?> setSelfAvatar(String? address, String? avatarPath, {bool notify = false}) async {
    if (address == null || address.isEmpty) return null;
    String profileVersion = Uuid().v4();
    String? avatarLocalPath = Path.convert2Local(avatarPath);
    var data = await setProfileVersion(address, profileVersion);
    bool success = false;
    if (data != null) success = await ContactStorage.instance.setAvatar(address, avatarLocalPath);
    if (success) {
      logger.i("$TAG - setSelfAvatar - success - avatarLocalPath:$avatarLocalPath - profileVersion:$profileVersion - address:$address");
      if (notify) queryAndNotify(address);
    } else {
      logger.w("$TAG - setSelfAvatar - fail - avatarLocalPath:$avatarLocalPath - profileVersion:$profileVersion - address:$address");
    }
    return success ? profileVersion : null;
  }

  Future<String?> setSelfFullName(String? address, String? firstName, String? lastName, {bool notify = false}) async {
    if (address == null || address.isEmpty) return null;
    String profileVersion = Uuid().v4();
    var data = await setProfileVersion(address, profileVersion);
    bool success = false;
    if (data != null) success = await ContactStorage.instance.setFullName(address, firstName ?? "", lastName ?? "");
    if (success) {
      logger.i("$TAG - setSelfFullName - success - firstName:$firstName - lastName:$lastName - profileVersion:$profileVersion - address:$address");
      if (notify) queryAndNotify(address);
    } else {
      logger.w("$TAG - setSelfFullName - fail - firstName:$firstName - lastName:$lastName - profileVersion:$profileVersion - address:$address");
    }
    return success ? profileVersion : null;
  }

  Future<String?> setOtherAvatar(String? address, String? profileVersion, String? avatarPath, {bool notify = false}) async {
    if (address == null || address.isEmpty) return null;
    String? avatarLocalPath = Path.convert2Local(avatarPath);
    bool success = await ContactStorage.instance.setAvatar(address, avatarLocalPath);
    if (success) await setProfileVersion(address, profileVersion);
    if (success) {
      logger.i("$TAG - setOtherAvatar - success - avatarLocalPath:$avatarLocalPath - profileVersion:$profileVersion - address:$address");
      if (notify) queryAndNotify(address);
    } else {
      logger.w("$TAG - setOtherAvatar - fail - avatarLocalPath:$avatarLocalPath - profileVersion:$profileVersion - address:$address");
    }
    return success ? profileVersion : null;
  }

  Future<String?> setOtherFullName(String? address, String? profileVersion, String? firstName, String? lastName, {bool notify = false}) async {
    if (address == null || address.isEmpty) return null;
    bool success = await ContactStorage.instance.setFullName(address, firstName ?? "", lastName ?? "");
    if (success) await setProfileVersion(address, profileVersion);
    if (success) {
      logger.i("$TAG - setOtherFullName - success - firstName:$firstName - lastName:$lastName - profileVersion:$profileVersion - address:$address");
      if (notify) queryAndNotify(address);
    } else {
      logger.w("$TAG - setOtherFullName - fail - firstName:$firstName - lastName:$lastName - profileVersion:$profileVersion - address:$address");
    }
    return success ? profileVersion : null;
  }

  Future<bool> setOtherRemarkName(String? address, String? remarkName, {bool notify = false}) async {
    if (address == null || address.isEmpty) return false;
    bool success = await ContactStorage.instance.setRemarkName(address, remarkName ?? "");
    if (success) {
      logger.i("$TAG - setOtherRemarkName - success - remarkName:$remarkName - address:$address");
      if (notify) queryAndNotify(address);
    } else {
      logger.w("$TAG - setOtherRemarkName - fail - remarkName:$remarkName - address:$address");
    }
    return success;
  }

  Future<bool> setType(String? address, int? type, {bool notify = false}) async {
    if (address == null || address.isEmpty || type == null || type == ContactType.me) return false;
    bool success = await ContactStorage.instance.setType(address, type);
    if (success) {
      logger.i("$TAG - setType - success - type:$type - address:$address");
      if (notify) queryAndNotify(address);
    } else {
      logger.w("$TAG - setType - fail - type:$type - address:$address");
    }
    return success;
  }

  Future<bool> setTop(String? address, bool top, {bool notify = false}) async {
    if (address == null || address.isEmpty) return false;
    bool success = await ContactStorage.instance.setTop(address, top);
    if (success) {
      logger.i("$TAG - setTop - success - top:$top - address:$address");
      if (notify) queryAndNotify(address);
    } else {
      logger.w("$TAG - setTop - fail - top:$top - address:$address");
    }
    return success;
  }

  Future<OptionsSchema?> setNotificationOpen(String? address, bool open, {bool notify = false}) async {
    if (address == null || address.isEmpty) return null;
    OptionsSchema? options = await ContactStorage.instance.setNotificationOpen(address, open);
    if (options != null) {
      logger.i("$TAG - setNotificationOpen - success - open:$open - options:$options - address:$address");
      if (notify) queryAndNotify(address);
    } else {
      logger.w("$TAG - setNotificationOpen - fail - open:$open - options:$options - address:$address");
    }
    return options;
  }

  Future<OptionsSchema?> setOptionsBurn(String? address, int? burningSeconds, int? updateAt, {bool notify = false}) async {
    if (address == null || address.isEmpty) return null;
    OptionsSchema? options = await ContactStorage.instance.setBurning(address, burningSeconds, updateAt);
    if (options != null) {
      logger.i("$TAG - setOptionsBurn - success - burningSeconds:$burningSeconds - updateAt:$updateAt - options:$options - address:$address");
      if (notify) queryAndNotify(address);
    } else {
      logger.w("$TAG - setOptionsBurn - fail - burningSeconds:$burningSeconds - updateAt:$updateAt - options:$options - address:$address");
    }
    return options;
  }

  Future<Map<String, dynamic>?> setOtherRemarkAvatar(String? address, String? avatarPath, {bool notify = false}) async {
    if (address == null || address.isEmpty) return null;
    String? avatarLocalPath = Path.convert2Local(avatarPath);
    Map<String, dynamic>? data = await ContactStorage.instance.setData(address, {
      "remarkAvatar": avatarLocalPath,
    });
    if (data != null) {
      logger.i("$TAG - setOtherRemarkAvatar - success - avatarLocalPath:$avatarLocalPath - data:$data - address:$address");
      if (notify) queryAndNotify(address);
    } else {
      logger.w("$TAG - setOtherRemarkAvatar - fail - avatarLocalPath:$avatarLocalPath - data:$data - address:$address");
    }
    return data;
  }

  Future<Map<String, dynamic>?> setWalletAddress(String? address, String? walletAddress, {bool notify = false}) async {
    if (address == null || address.isEmpty) return null;
    Map<String, dynamic>? data = await ContactStorage.instance.setData(address, {
      "nknWalletAddress": walletAddress,
    });
    if (data != null) {
      logger.i("$TAG - setWalletAddress - success - walletAddress:$walletAddress - data:$data - address:$address");
      if (notify) queryAndNotify(address);
    } else {
      logger.w("$TAG - setWalletAddress - fail - walletAddress:$walletAddress - data:$data - address:$address");
    }
    return data;
  }

  Future<Map<String, dynamic>?> setMappedAddress(String? address, List<String>? mapped, {bool notify = false}) async {
    if (address == null || address.isEmpty) return null;
    Map<String, dynamic>? data = await ContactStorage.instance.setData(address, {
      "mappedAddress": mapped,
    });
    if (data != null) {
      logger.i("$TAG - setMappedAddress - success - mapped:$mapped - data:$data - address:$address");
      if (notify) queryAndNotify(address);
    } else {
      logger.w("$TAG - setMappedAddress - fail - mapped:$mapped - data:$data - address:$address");
    }
    return data;
  }

  Future<Map<String, dynamic>?> setProfileVersion(String? address, String? profileVersion, {bool notify = false}) async {
    if (address == null || address.isEmpty) return null;
    var data = await ContactStorage.instance.setData(address, {
      "profileVersion": profileVersion,
    });
    if (data != null) {
      logger.i("$TAG - setProfileVersion - success - profileVersion:$profileVersion - data:$data - address:$address");
      if (notify) queryAndNotify(address);
    } else {
      logger.w("$TAG - setProfileVersion - fail - profileVersion:$profileVersion - data:$data - address:$address");
    }
    return data;
  }

  Future<Map<String, dynamic>?> setNotes(String? address, String? notes, {bool notify = false}) async {
    if (address == null || address.isEmpty) return null;
    Map<String, dynamic>? data = await ContactStorage.instance.setData(address, {
      "notes": notes,
    });
    if (data != null) {
      logger.i("$TAG - setNotes - success - notes:$notes - data:$data - address:$address");
      if (notify) queryAndNotify(address);
    } else {
      logger.w("$TAG - setNotes - fail - notes:$notes - data:$data - address:$address");
    }
    return data;
  }

  Future<Map<String, dynamic>?> setReceivedMessages(String? address, Map adds, List<String> dels, {bool notify = false}) async {
    if (address == null || address.isEmpty) return null;
    var data = await ContactStorage.instance.setDataItemMapChange(address, "receivedMessages", adds, dels);
    if (data != null) {
      logger.i("$TAG - setReceivedMessages - success - adds:$adds - dels:$dels - data:$data - address:$address");
      if (notify) queryAndNotify(address);
    } else {
      logger.w("$TAG - setReceivedMessages - fail - adds:$adds - dels:$dels - data:$data - address:$address");
    }
    return data;
  }

  Future<Map<String, dynamic>?> setTipNotification(String? address, int? timeAt, {bool notify = false}) async {
    if (address == null || address.isEmpty) return null;
    Map<String, dynamic>? data = await ContactStorage.instance.setData(address, {
      "tipNotification": timeAt ?? DateTime.now().millisecondsSinceEpoch,
    });
    if (data != null) {
      logger.i("$TAG - setTipNotification - success - timeAt:$timeAt - data:$data - address:$address");
      if (notify) queryAndNotify(address);
    } else {
      logger.w("$TAG - setTipNotification - fail - timeAt:$timeAt - data:$data - address:$address");
    }
    return data;
  }

  Future queryAndNotify(String? address) async {
    if (address == null || address.isEmpty) return;
    ContactSchema? updated = await query(address);
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

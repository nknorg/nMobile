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
    ContactSchema? contact = await queryByClientAddress(clientAddress);
    // add
    if (canAdd) {
      if (contact != null) {
        if (contact.type == ContactType.none) {
          bool success = await setType(contact.id, ContactType.stranger, notify: true);
          if (success) contact.type = ContactType.stranger;
        }
      } else {
        contact = await addByType(clientAddress, ContactType.stranger, notify: true);
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
      contact = await addByType(myAddress, ContactType.me, notify: true);
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
        await setWalletAddress(contact, nknWalletAddress);
      }
    }
    logger.d("$TAG - getMe - canAdd:$canAdd - fetchWallet:$needWallet - contact:$contact");
    return contact;
  }

  Future<ContactSchema?> addByType(String? clientAddress, int contactType, {bool notify = false}) async {
    if (clientAddress == null || clientAddress.isEmpty) return null;
    ContactSchema? schema = await ContactSchema.create(clientAddress, contactType);
    return await add(schema, notify: notify);
  }

  Future<ContactSchema?> add(ContactSchema? schema, {bool notify = false}) async {
    if (schema == null || schema.clientAddress.isEmpty) return null;
    schema.nknWalletAddress = await schema.tryNknWalletAddress();
    logger.d("$TAG - add - schema:$schema");
    ContactSchema? added = await ContactStorage.instance.insert(schema);
    if ((added != null) && notify) _addSink.add(added);
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
      logger.d("$TAG - queryByClientAddress - nknWalletAddress:$nknWalletAddress");
      await setWalletAddress(_schema, nknWalletAddress);
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
    logger.d("$TAG - setNotificationOpen - start - open:$open - old:${schema.options} - contact:$schema");
    OptionsSchema? options = await ContactStorage.instance.setNotificationOpen(schema.id, open);
    if (options != null) {
      logger.i("$TAG - setNotificationOpen - end success - new:$options - contact:$schema");
      schema.options = options;
      if (notify) queryAndNotify(schema.id);
    } else {
      logger.w("$TAG - setNotificationOpen - end fail - open:$open - old:${schema.options} - contact:$schema");
    }
    return options != null;
  }

  Future<bool> setOptionsBurn(ContactSchema? schema, int? burningSeconds, int? updateAt, {bool notify = false}) async {
    if (schema == null || schema.id == null || schema.id == 0) return false;
    logger.d("$TAG - setOptionsBurn - start - burningSeconds:$burningSeconds - updateAt:$updateAt - old:${schema.options} - contact:$schema");
    OptionsSchema? options = await ContactStorage.instance.setBurning(schema.id, burningSeconds, updateAt);
    if (options != null) {
      logger.i("$TAG - setOptionsBurn - end success - new:$options - contact:$schema");
      schema.options = options;
      if (notify) queryAndNotify(schema.id);
    } else {
      logger.w("$TAG - setOptionsBurn - end fail - burningSeconds:$burningSeconds - updateAt:$updateAt - old:${schema.options} - contact:$schema");
    }
    return options != null;
  }

  Future<bool> setRemarkAvatar(ContactSchema? schema, String? avatarLocalPath, {bool notify = false}) async {
    if (schema == null || schema.id == 0) return false;
    logger.d("$TAG - setRemarkAvatar - start - new_avatar_path:$avatarLocalPath - old:${schema.data} - contact:$schema");
    Map<String, dynamic>? data = await ContactStorage.instance.setData(schema.id, {
      "remarkAvatar": avatarLocalPath,
    });
    if (data != null) {
      logger.i("$TAG - setRemarkAvatar - end success - new:$data - contact:$schema");
      schema.data = data;
      if (notify) queryAndNotify(schema.id);
    } else {
      logger.w("$TAG - setRemarkAvatar - end fail - new_avatar_path:$avatarLocalPath - old:${schema.data} - contact:$schema");
    }
    return data != null;
  }

  Future<bool> setRemarkName(ContactSchema? schema, String? remarkName, {bool notify = false}) async {
    if (schema == null || schema.id == 0) return false;
    logger.d("$TAG - setRemarkName - start - new_name:$remarkName - old:${schema.data} - contact:$schema");
    Map<String, dynamic>? data = await ContactStorage.instance.setData(schema.id, {
      "remarkName": remarkName,
    });
    if (data != null) {
      logger.i("$TAG - setRemarkName - end success - new:$data - contact:$schema");
      schema.data = data;
      if (notify) queryAndNotify(schema.id);
    } else {
      logger.w("$TAG - setRemarkName - end fail - new_name:$remarkName - old:${schema.data} - contact:$schema");
    }
    return data != null;
  }

  Future<bool> setNotes(ContactSchema? schema, String? notes, {bool notify = false}) async {
    if (schema == null || schema.id == null || schema.id == 0) return false;
    logger.d("$TAG - setNotes - start - notes:$notes - old:${schema.data} - contact:$schema");
    Map<String, dynamic>? data = await ContactStorage.instance.setData(schema.id, {
      "notes": notes,
    });
    if (data != null) {
      logger.i("$TAG - setNotes - end success - new:$data - contact:$schema");
      schema.data = data;
      if (notify) queryAndNotify(schema.id);
    } else {
      logger.w("$TAG - setNotes - end fail - notes:$notes - old:${schema.data} - contact:$schema");
    }
    return data != null;
  }

  Future<bool> setWalletAddress(ContactSchema? schema, String? walletAddress, {bool notify = false}) async {
    if (schema == null || schema.id == null || schema.id == 0) return false;
    logger.d("$TAG - setWalletAddress - start - walletAddress:$walletAddress - old:${schema.data} - contact:$schema");
    Map<String, dynamic>? data = await ContactStorage.instance.setData(schema.id, {
      "nknWalletAddress": walletAddress,
    });
    if (data != null) {
      logger.i("$TAG - setWalletAddress - end success - new:$data - contact:$schema");
      schema.data = data;
      if (notify) queryAndNotify(schema.id);
    } else {
      logger.w("$TAG - setWalletAddress - end fail - walletAddress:$walletAddress - old:${schema.data} - contact:$schema");
    }
    return data != null;
  }

  Future<bool> setMappedAddress(ContactSchema? schema, List<String>? mapped, {bool notify = false}) async {
    if (schema == null || schema.id == null || schema.id == 0) return false;
    logger.d("$TAG - setMappedAddress - start - mapped:$mapped - old:${schema.data} - contact:$schema");
    Map<String, dynamic>? data = await ContactStorage.instance.setData(schema.id, {
      "mappedAddress": mapped,
    });
    if (data != null) {
      logger.i("$TAG - setMappedAddress - end success - new:$data - contact:$schema");
      schema.data = data;
      if (notify) queryAndNotify(schema.id);
    } else {
      logger.w("$TAG - setMappedAddress - end fail - mapped:$mapped - old:${schema.data} - contact:$schema");
    }
    return data != null;
  }

  Future<bool> setTipNotification(ContactSchema? schema, {bool notify = false}) async {
    if (schema == null || schema.id == null || schema.id == 0) return false;
    logger.d("$TAG - setTipNotification - start - old:${schema.data} - contact:$schema");
    Map<String, dynamic>? data = await ContactStorage.instance.setData(schema.id, {
      "tipNotification": DateTime.now().millisecondsSinceEpoch,
    });
    if (data != null) {
      logger.i("$TAG - setTipNotification - end success - new:$data - contact:$schema");
      schema.data = data;
      if (notify) queryAndNotify(schema.id);
    } else {
      logger.w("$TAG - setTipNotification - end fail - old:${schema.data} - contact:$schema");
    }
    return data != null;
  }

  Future<String?> joinQueueIdsByClientAddress(String? clientAddress) async {
    if (clientAddress == null || clientAddress.isEmpty) return null;
    ContactSchema? contact = await queryByClientAddress(clientAddress);
    return joinQueueIdsByContact(contact);
  }

  String? joinQueueIdsByContact(ContactSchema? contact) {
    if (contact == null) return null;
    int latestSendMessageQueueId = contact.latestSendMessageQueueId;
    int latestReceivedMessageQueueId = contact.latestReceivedMessageQueueId;
    List<int> lostReceiveMessageQueueIds = contact.lostReceiveMessageQueueIds;
    return joinQueueIds(latestSendMessageQueueId, latestReceivedMessageQueueId, lostReceiveMessageQueueIds);
  }

  String? joinQueueIds(int latestSendMessageQueueId, int latestReceivedMessageQueueId, List<int> lostReceiveMessageQueueIds) {
    if ((latestSendMessageQueueId <= 0) && (latestReceivedMessageQueueId <= 0) && lostReceiveMessageQueueIds.isEmpty) return null;
    return "${latestSendMessageQueueId}_::_${latestReceivedMessageQueueId}_::_${lostReceiveMessageQueueIds.join(".")}";
  }

  List<dynamic> splitQueueIds(String? queueIds) {
    if (queueIds == null || queueIds.isEmpty) return [0, 0, []];
    List<String> splits = queueIds.split("_::_");
    if (splits.length < 3) return [0, 0, []];
    int latestSendMessageQueueId = int.tryParse(splits[0].toString()) ?? 0;
    int latestReceivedMessageQueueId = int.tryParse(splits[1].toString()) ?? 0;
    List<int> lostReceiveMessageQueueIds = splits[2].split(".").map((e) => int.tryParse(e.toString()) ?? 0).toList()..removeWhere((element) => element == 0);
    return [latestSendMessageQueueId, latestReceivedMessageQueueId, lostReceiveMessageQueueIds];
  }

  Future<bool> setLatestSendMessageQueueId(ContactSchema? schema, int queueId) async {
    if (schema == null || schema.id == null || schema.id == 0) return false;
    var data = await ContactStorage.instance.setData(schema.id, {
      "latestSendMessageQueueId": queueId,
    });
    logger.d("$TAG - setLatestSendMessageQueueId - queueId:$queueId - new:$data - contactAddress:${schema.clientAddress}");
    return data != null;
  }

  Future<bool> setSendingMessageQueueIds(String? clientAddress, Map addPairs, List<int> delQueueIds) async {
    if (clientAddress == null || clientAddress.isEmpty) return false;
    var data = await ContactStorage.instance.setDataItemMapChange(clientAddress, "sendingMessageQueueIds", addPairs, delQueueIds);
    logger.d("$TAG - setSendingMessageQueueIds - addPairs:$addPairs - delQueueIds:$delQueueIds - new:$data - clientAddress:$clientAddress");
    return data != null;
  }

  Future<bool> setLatestReceivedMessageQueueId(ContactSchema? schema, int queueId) async {
    if (schema == null || schema.id == null || schema.id == 0) return false;
    var data = await ContactStorage.instance.setData(schema.id, {
      "latestReceivedMessageQueueId": queueId,
    });
    logger.d("$TAG - setLatestReceivedMessageQueueId - queueId:$queueId - new:$data - contactAddress:${schema.clientAddress}");
    return data != null;
  }

  Future<bool> setLostReceiveMessageQueueIds(String? clientAddress, List<int> adds, List<int> dels) async {
    if (clientAddress == null || clientAddress.isEmpty) return false;
    var data = await ContactStorage.instance.setDataItemListChange(clientAddress, "lostReceiveMessageQueueIds", adds, dels);
    logger.d("$TAG - setLostReceiveMessageQueueIds - adds:$adds - dels:$dels - new:$data - clientAddress:$clientAddress");
    return data != null;
  }

  Future<bool> setRemoteLatestReceivedMessageQueueId(ContactSchema? schema, int queueId) async {
    if (schema == null || schema.id == null || schema.id == 0) return false;
    var data = await ContactStorage.instance.setData(schema.id, {
      "remoteLatestReceivedMessageQueueId": queueId,
    });
    logger.d("$TAG - setRemoteLatestReceivedMessageQueueId - queueId:$queueId - new:$data - contactAddress:${schema.clientAddress}");
    return data != null;
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

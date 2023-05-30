import 'dart:convert';
import 'dart:io';

import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/validate.dart';
import 'package:nmobile/schema/option.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/util.dart';

class ContactType {
  static const me = -1;
  static const none = 0;
  static const stranger = 1;
  static const friend = 2;
}

class ContactRequestType {
  static const header = 'header';
  static const full = 'full';
}

class ContactSchema {
  int? id; // <- id
  int createAt; // <-> create_at
  int updateAt; // <-> update_at

  String address; // (required : (ID).PubKey) <-> address (same with client.address)

  File? avatar; // (local_path) <-> avatar
  String firstName; // (required : name) <-> first_name
  String lastName; // <-> last_name
  String remarkName; // <-> last_name

  int type; // (required) <-> type
  bool isTop; // <-> is_top

  OptionsSchema options = OptionsSchema(); // <-> options
  Map<String, dynamic> data = Map(); // [*]<-> data[*, avatar, firstName, notes, nknWalletAddress, ...]

  ContactSchema({
    this.id,
    this.createAt = 0,
    this.updateAt = 0,
    required this.address,
    this.avatar,
    this.firstName = "",
    this.lastName = "",
    this.remarkName = "",
    this.type = ContactType.none,
    this.isTop = false,
  }) {
    if (createAt == 0) createAt = DateTime.now().millisecondsSinceEpoch;
    if (updateAt == 0) updateAt = DateTime.now().millisecondsSinceEpoch;
  }

  static ContactSchema? create(String? address, int? type) {
    if (address == null || address.isEmpty) return null;
    return ContactSchema(
      createAt: DateTime.now().millisecondsSinceEpoch,
      updateAt: DateTime.now().millisecondsSinceEpoch,
      address: address,
      firstName: getDefaultName(address),
      type: type ?? ContactType.none,
    );
  }

  static String getDefaultName(String? address) {
    if (address == null || address.isEmpty) return "";
    String defaultName;
    if (address.length <= 6) {
      defaultName = address;
    }
    var index = address.lastIndexOf('.');
    if (index < 0) {
      defaultName = address.substring(0, 6);
    } else {
      defaultName = address.substring(0, index + 7);
    }
    return defaultName;
  }

  String get pubKey {
    return getPubKeyFromTopicOrChatId(address) ?? address;
  }

  bool get isMe {
    return type == ContactType.me;
  }

  String get fullName {
    return firstName + lastName;
  }

  String get displayName {
    String displayName = remarkName;
    if (displayName.isEmpty) {
      displayName = fullName.isNotEmpty ? fullName : getDefaultName(address);
    }
    return displayName;
  }

  String? get remarkAvatarLocalPath {
    return data['remarkAvatar']?.toString();
  }

  String? get displayAvatarLocalPath {
    String? avatarLocalPath;
    // remark
    if (data.isNotEmpty == true) {
      if (data['remarkAvatar']?.toString().isNotEmpty == true) {
        avatarLocalPath = data['remarkAvatar'];
      }
    }
    // original
    if ((avatarLocalPath == null) || avatarLocalPath.isEmpty) {
      avatarLocalPath = avatar?.path;
    }
    return avatarLocalPath;
  }

  String? get displayAvatarPath {
    String? avatarLocalPath = displayAvatarLocalPath;
    if ((avatarLocalPath == null) || avatarLocalPath.isEmpty) {
      return null;
    }
    String? completePath = Path.convert2Complete(avatarLocalPath);
    if ((completePath == null) || completePath.isEmpty) {
      return null;
    }
    return completePath;
  }

  Future<File?> get displayAvatarFile async {
    String? completePath = displayAvatarPath;
    if (completePath == null || completePath.isEmpty) {
      return Future.value(null);
    }
    // file
    File avatarFile = File(completePath);
    bool exits = await avatarFile.exists();
    if (!exits) {
      return Future.value(null);
    }
    return avatarFile;
  }

  Future<String> get nknWalletAddress async {
    String value = data['nknWalletAddress']?.toString() ?? "";
    value = value.replaceAll("\n", "").trim();
    if (value.isNotEmpty) return value;
    try {
      if (Validate.isNknPublicKey(pubKey)) {
        value = (await Wallet.pubKeyToWalletAddr(pubKey)) ?? "";
      }
    } catch (e, st) {
      handleError(e, st);
    }
    data['nknWalletAddress'] = value;
    return value;
  }

  List<String> get mappedAddress {
    return (data['mappedAddress'] ?? []).cast<String>();
  }

  String? get profileVersion {
    return data['profileVersion']?.toString().replaceAll("\n", "").trim();
  }

  String? get notes {
    return data['notes']?.toString();
  }

  Map<String, int> get receivedMessages {
    Map<String, dynamic> values = data['receivedMessages'] ?? Map();
    return values.map((key, value) => MapEntry(key.toString(), int.tryParse(value?.toString() ?? "") ?? 0))..removeWhere((key, value) => key.isEmpty || value == 0);
  }

  bool get tipNotification {
    return (int.tryParse(data['tipNotification']?.toString() ?? "0") ?? 0) > 0;
  }

  Map<String, dynamic> toMap() {
    address = address.replaceAll("\n", "").trim();
    Map<String, dynamic> map = {
      'create_at': createAt,
      'update_at': updateAt,
      'address': address,
      'avatar': Path.convert2Local(avatar?.path),
      'first_name': firstName.isEmpty ? getDefaultName(address) : firstName,
      'last_name': lastName,
      'remark_name': remarkName,
      'type': type,
      'is_top': isTop ? 1 : 0,
      'options': jsonEncode(options.toMap()),
      'data': jsonEncode(data),
    };
    return map;
  }

  static ContactSchema fromMap(Map e) {
    var contact = ContactSchema(
      id: e['id'],
      createAt: e['create_at'] ?? DateTime.now().millisecondsSinceEpoch,
      updateAt: e['update_at'] ?? DateTime.now().millisecondsSinceEpoch,
      address: e['address'] ?? "",
      avatar: Path.convert2Complete(e['avatar']) != null ? File(Path.convert2Complete(e['avatar'])!) : null,
      firstName: (e['first_name']?.toString() ?? "").isEmpty ? getDefaultName(e['address']) : e['first_name'],
      lastName: e['last_name'] ?? "",
      remarkName: e['remark_name'] ?? "",
      type: e['type'] ?? ContactType.none,
      isTop: (e['is_top'] != null) && (e['is_top'] == 1) ? true : false,
    );
    contact.address = contact.address.replaceAll("\n", "").trim();
    if (e['options']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? options = Util.jsonFormatMap(e['options']);
      contact.options = OptionsSchema.fromMap(options ?? Map());
    }
    if (e['data']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? data = Util.jsonFormatMap(e['data']);
      if (data != null) contact.data.addAll(data);
    }
    return contact;
  }

  @override
  String toString() {
    return 'ContactSchema{id: $id, createAt: $createAt, updateAt: $updateAt, address: $address, avatar: $avatar, firstName: $firstName, lastName: $lastName, remarkName: $remarkName, type: $type, isTop: $isTop, options: $options, data: $data}';
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/client/client.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/helpers/validate.dart';
import 'package:nmobile/schema/option.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/util.dart';
import 'package:uuid/uuid.dart';

class ContactType {
  static const me = -1;
  static const none = 0;
  static const stranger = 1;
  static const friend = 2;
// static const String stranger = 'stranger';
// static const String friend = 'friend';
// static const String me = 'me';
}

class ContactRequestType {
  static const header = 'header';
  static const full = 'full';
}

class ContactSchema {
  int? id; // <- id
  int? createAt; // <-> create_at
  int? updateAt; // <-> update_at

  String clientAddress; // (required : (ID).PubKey) <-> address (same with client.address)
  int? type; // (required) <-> type

  File? avatar; // (local_path) <-> avatar
  String? firstName; // (required : name) <-> first_name
  String? lastName; // <-> last_name
  String? profileVersion; // <-> profile_version
  // int? profileUpdateAt; // <-> profile_expires_at(long) == update_at // FUTURE:GG multi_device_sync

  bool isTop = false; // <-> is_top
  @Deprecated('replace by DeviceInfo.deviceToken')
  String? deviceToken; // <-> device_token

  OptionsSchema? options; // <-> options
  Map<String, dynamic>? data; // [*]<-> data[*, avatar, firstName, notes, nknWalletAddress, ...]

  // extra
  String? nknWalletAddress; // == extraInfo[nknWalletAddress] <-> data[nknWalletAddress]

  ContactSchema({
    this.id,
    this.createAt,
    this.updateAt,
    required this.clientAddress,
    this.type,
    this.avatar,
    this.firstName,
    this.lastName,
    this.profileVersion,
    this.isTop = false,
    this.deviceToken,
    this.options,
    this.data,
    // extra
    this.nknWalletAddress,
  }) {
    if (options == null) {
      options = OptionsSchema();
    }
  }

  static Future<ContactSchema?> create(String? clientAddress, int? type, {String? profileVersion}) async {
    if (clientAddress == null || clientAddress.isEmpty) return null;
    ContactSchema? schema = createWithNoWalletAddress(clientAddress, type, profileVersion: profileVersion);
    if (schema == null) return null;
    String? walletAddress;
    try {
      String? pubKey = getPubKeyFromTopicOrChatId(clientAddress);
      if (Validate.isNknPublicKey(pubKey)) {
        walletAddress = await Wallet.pubKeyToWalletAddr(pubKey!);
      }
    } catch (e, st) {
      handleError(e, st);
    }
    schema.nknWalletAddress = walletAddress;
    return schema;
  }

  static ContactSchema? createWithNoWalletAddress(String? clientAddress, int? type, {String? profileVersion}) {
    if (clientAddress == null || clientAddress.isEmpty) return null;
    return ContactSchema(
      createAt: DateTime.now().millisecondsSinceEpoch,
      updateAt: DateTime.now().millisecondsSinceEpoch,
      clientAddress: clientAddress,
      type: type,
      profileVersion: profileVersion ?? Uuid().v4(),
    );
  }

  static getDefaultName(String? clientAddress) {
    if (clientAddress == null || clientAddress.isEmpty) return null;
    String defaultName;
    var index = clientAddress.lastIndexOf('.');
    if (clientAddress.length <= 6) {
      defaultName = clientAddress;
    } else if (index < 0) {
      defaultName = clientAddress.substring(0, 6);
    } else {
      defaultName = clientAddress.substring(0, index + 7);
    }
    return defaultName;
  }

  String get pubKey {
    return getPubKeyFromTopicOrChatId(clientAddress) ?? clientAddress;
  }

  bool get isMe {
    if (type == ContactType.me) {
      return true;
    } else {
      return false;
    }
  }

  String get fullName {
    return firstName ?? ""; // lastName
  }

  String? get remarkName {
    return data?['remarkName'] ?? data?['firstName'];
  }

  String get displayName {
    String? displayName;
    // remark
    if (data?.isNotEmpty == true) {
      if (data?['remarkName']?.toString().isNotEmpty == true) {
        displayName = data?['remarkName'];
      } else if (data?['firstName']?.toString().isNotEmpty == true) {
        displayName = data?['firstName'];
      }
    }
    // original
    if (displayName == null || displayName.isEmpty) {
      if (firstName?.toString().isNotEmpty == true) {
        displayName = firstName;
      } else {
        displayName = getDefaultName(clientAddress);
      }
    }
    return displayName ?? "";
  }

  String? get remarkAvatarLocalPath {
    return data?['remarkAvatar'] ?? data?['avatar'];
  }

  String? get displayAvatarLocalPath {
    String? avatarLocalPath;
    // remark
    if (data?.toString().isNotEmpty == true) {
      if (data?['remarkAvatar']?.toString().isNotEmpty == true) {
        avatarLocalPath = data?['remarkAvatar'];
      } else if (data?['avatar']?.toString().isNotEmpty == true) {
        avatarLocalPath = data?['avatar'];
      }
    }
    // original
    if (avatarLocalPath == null || avatarLocalPath.isEmpty) {
      avatarLocalPath = avatar?.path;
    }
    return avatarLocalPath;
  }

  String? get displayAvatarPath {
    String? avatarLocalPath = displayAvatarLocalPath;
    if (avatarLocalPath == null || avatarLocalPath.isEmpty) {
      return null;
    }
    String? completePath = Path.convert2Complete(avatarLocalPath);
    if (completePath == null || completePath.isEmpty) {
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

  String? get notes {
    return data?['notes'];
  }

  List<String> get mappedAddress {
    return (data?['mappedAddress'] ?? []).cast<String>();
  }

  Future<String?> tryNknWalletAddress({bool force = false}) async {
    if ((nknWalletAddress?.isNotEmpty == true) && !force) return nknWalletAddress;
    try {
      if (Validate.isNknPublicKey(pubKey)) {
        nknWalletAddress = await Wallet.pubKeyToWalletAddr(pubKey);
      }
    } catch (e, st) {
      handleError(e, st);
    }
    return nknWalletAddress;
  }

  Map<String, dynamic> toMap() {
    if (data == null) {
      data = new Map<String, dynamic>();
    }
    if (nknWalletAddress?.isNotEmpty == true) {
      data?['nknWalletAddress'] = nknWalletAddress?.replaceAll("\n", "").trim();
    } else {
      // data?['nknWalletAddress'] = await tryNknWalletAddress();
    }
    if (data?.keys.length == 0) {
      data = null;
    }

    if (options == null) {
      options = OptionsSchema();
    }

    clientAddress = clientAddress.replaceAll("\n", "").trim();
    profileVersion = profileVersion?.replaceAll("\n", "").trim();
    deviceToken = deviceToken?.replaceAll("\n", "").trim();

    Map<String, dynamic> map = {
      'create_at': createAt ?? DateTime.now().millisecondsSinceEpoch,
      'update_at': updateAt ?? DateTime.now().millisecondsSinceEpoch,
      'address': clientAddress,
      'type': type,
      'avatar': Path.convert2Local(avatar?.path),
      'first_name': firstName ?? getDefaultName(clientAddress),
      'last_name': lastName,
      'profile_version': profileVersion,
      'is_top': isTop ? 1 : 0,
      'device_token': deviceToken,
      'options': options != null ? jsonEncode(options?.toMap() ?? Map()) : null,
      'data': (data?.isNotEmpty == true) ? jsonEncode(data) : '{}',
    };
    return map;
  }

  static ContactSchema fromMap(Map e) {
    var contact = ContactSchema(
      id: e['id'],
      createAt: e['create_at'],
      updateAt: e['update_at'],
      clientAddress: e['address'] ?? "",
      type: e['type'],
      avatar: Path.convert2Complete(e['avatar']) != null ? File(Path.convert2Complete(e['avatar'])!) : null,
      firstName: e['first_name'] ?? getDefaultName(e['address']),
      lastName: e['last_name'],
      profileVersion: e['profile_version'],
      isTop: (e['is_top'] != null) && (e['is_top'] == 1) ? true : false,
      deviceToken: e['device_token'],
    );

    contact.clientAddress = contact.clientAddress.replaceAll("\n", "").trim();
    contact.profileVersion = contact.profileVersion?.replaceAll("\n", "").trim();
    contact.deviceToken = contact.deviceToken?.replaceAll("\n", "").trim();

    if (e['options']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? options = Util.jsonFormatMap(e['options']);
      contact.options = OptionsSchema.fromMap(options ?? Map());
    }
    if (contact.options == null) {
      contact.options = OptionsSchema();
    }

    if (e['data']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? data = Util.jsonFormatMap(e['data']);

      if (contact.data == null) {
        contact.data = new Map<String, dynamic>();
      }
      if (data != null) {
        contact.data?.addAll(data);
      }
      contact.nknWalletAddress = data?['nknWalletAddress']?.toString().replaceAll("\n", "").trim();
      // contact.nknWalletAddress = await contact.tryNknWalletAddress();
    }
    return contact;
  }

  @override
  String toString() {
    return 'ContactSchema{id: $id, createAt: $createAt, updateAt: $updateAt, clientAddress: $clientAddress, type: $type, avatar: $avatar, firstName: $firstName, lastName: $lastName, profileVersion: $profileVersion, isTop: $isTop, deviceToken: $deviceToken, options: $options, data: $data, nknWalletAddress: $nknWalletAddress}';
  }
}

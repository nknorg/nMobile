import 'dart:convert';
import 'dart:io';

import 'package:nkn_sdk_flutter/wallet.dart';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/utils/path.dart';
import 'package:nmobile/utils/utils.dart';
import 'package:uuid/uuid.dart';

import 'option.dart';

class ContactSchema {
  int? id; // <- id
  String clientAddress; // (required : (ID).PubKey) <-> address (same with client.address)
  String? type; // (required) <-> type
  DateTime? createdAt; // <-> created_time
  DateTime? updatedAt; // <-> updated_time

  File? avatar; // (local_path) <-> avatar
  String? firstName; // (required : name) <-> first_name
  String? lastName; // <-> last_name
  String? profileVersion; // <-> profile_version
  DateTime? profileUpdateAt; // <-> profile_expires_at(long) == update_at

  bool isTop = false; // <-> is_top
  String? deviceToken; // <-> device_token
  bool notificationOpen = false; // <-> notification_open

  OptionsSchema? options; // <-> options
  Map<String, dynamic>? data; // [*]<-> data[*, avatar, firstName, notes, nknWalletAddress, ...]

  // extra
  String? nknWalletAddress; // == extraInfo[nknWalletAddress] <-> data[nknWalletAddress]

  ContactSchema({
    this.id,
    required this.clientAddress,
    this.type,
    this.createdAt,
    this.updatedAt,
    this.avatar,
    this.firstName,
    this.lastName,
    this.profileVersion,
    this.profileUpdateAt,
    this.isTop = false,
    this.deviceToken,
    this.notificationOpen = false,
    this.options,
    this.data,
    // extra
    this.nknWalletAddress,
  }) {
    if (options == null) {
      options = OptionsSchema();
    }
  }

  static Future<ContactSchema?> createByType(String? clientAddress, {String? type}) async {
    if (clientAddress == null || clientAddress.isEmpty) return null;
    String? walletAddress = await Wallet.pubKeyToWalletAddr(getPublicKeyByClientAddr(clientAddress));
    return ContactSchema(
      clientAddress: clientAddress,
      type: type,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      profileVersion: Uuid().v4(),
      nknWalletAddress: walletAddress,
    );
  }

  static getDefaultName(String? clientAddress) {
    if (clientAddress == null || clientAddress.isEmpty) return null;
    String defaultName;
    var index = clientAddress.lastIndexOf('.');
    if (index < 0) {
      defaultName = clientAddress.substring(0, 6);
    } else {
      defaultName = clientAddress.substring(0, index + 7);
    }
    return defaultName;
  }

  bool get isMe {
    if (type == ContactType.me) {
      return true;
    } else {
      return false;
    }
  }

  String get fullName {
    return firstName ?? "";
  }

  String get displayName {
    String? displayName;

    if (data?.isNotEmpty == true) {
      if (data!['firstName']?.toString().isNotEmpty == true) {
        displayName = data!['firstName'];
      }
      // SUPPORT:START
      else if (data!['remark_name']?.toString().isNotEmpty == true) {
        displayName = data!['remark_name'];
      } else if (data!['notes']?.toString().isNotEmpty == true) {
        displayName = data!['notes'];
      }
      // SUPPORT:END
    }

    if (displayName == null || displayName.isEmpty) {
      if (firstName?.toString().isNotEmpty == true) {
        displayName = firstName;
      }
    }

    if (displayName == null || displayName.isEmpty) {
      displayName = getDefaultName(clientAddress);
    }
    return displayName ?? "";
  }

  Future<File?> get displayAvatarFile async {
    String? avatarLocalPath;

    if (data?.toString().isNotEmpty == true) {
      if (data!['avatar']?.toString().isNotEmpty == true) {
        avatarLocalPath = data!['avatar'];
      }
      // SUPPORT:START
      else if (data!['remark_avatar']?.toString().isNotEmpty == true) {
        avatarLocalPath = data!['remark_avatar'];
      }
      // SUPPORT:END
    }

    if (avatarLocalPath == null || avatarLocalPath.isEmpty) {
      avatarLocalPath = avatar?.path;
    }
    if (avatarLocalPath == null || avatarLocalPath.isEmpty) {
      return Future.value(null);
    }
    String? completePath = Path.getCompleteFile(avatarLocalPath);
    if (completePath == null || completePath.isEmpty) {
      return Future.value(null);
    }
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

  Future<Map<String, dynamic>> toMap() async {
    if (data == null) {
      data = new Map<String, dynamic>();
    }
    if (nknWalletAddress?.isNotEmpty == true) {
      data?['nknWalletAddress'] = nknWalletAddress;
    } else {
      data?['nknWalletAddress'] = await Wallet.pubKeyToWalletAddr(getPublicKeyByClientAddr(clientAddress));
    }
    if (notes?.isNotEmpty == true) {
      data?['notes'] = notes;
    }
    if (data?.keys.length == 0) {
      data = null;
    }

    if (options == null) {
      options = OptionsSchema();
    }

    Map<String, dynamic> map = {
      'address': clientAddress,
      'type': type,
      'created_time': createdAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'updated_time': updatedAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'avatar': Path.getLocalFile(avatar?.path),
      'first_name': firstName ?? getDefaultName(clientAddress),
      'last_name': lastName,
      'profile_version': profileVersion ?? Uuid().v4(),
      'profile_expires_at': profileUpdateAt?.millisecondsSinceEpoch,
      'is_top': isTop ? 1 : 0,
      'device_token': deviceToken,
      'notification_open': notificationOpen ? 1 : 0,
      'options': options != null ? jsonEncode(options!.toMap()) : null,
      'data': (data?.isNotEmpty == true) ? jsonEncode(data) : '{}',
    };
    return map;
  }

  static Future<ContactSchema> fromMap(Map e) async {
    var contact = ContactSchema(
      id: e['id'],
      clientAddress: e['address'] ?? "",
      type: e['type'],
      createdAt: e['created_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['created_time']) : null,
      updatedAt: e['updated_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['updated_time']) : null,
      avatar: Path.getCompleteFile(e['avatar']) != null ? File(Path.getCompleteFile(e['avatar'])!) : null,
      firstName: e['first_name'] ?? getDefaultName(e['address']),
      lastName: e['last_name'],
      profileVersion: e['profile_version'],
      profileUpdateAt: e['profile_expires_at'] != null ? DateTime.fromMillisecondsSinceEpoch(e['profile_expires_at']) : null,
      isTop: (e['is_top'] != null) && (e['is_top'] == 1) ? true : false,
      deviceToken: e['device_token'],
      notificationOpen: (e['notification_open'] != null && e['notification_open'].toString() == '1') ? true : false,
    );

    if (e['options']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? options = jsonFormat(e['options']);
      contact.options = OptionsSchema.fromMap(options ?? Map());
    }
    if (contact.options == null) {
      contact.options = OptionsSchema();
    }

    if (e['data']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? data = jsonFormat(e['data']);

      if (contact.data == null) {
        contact.data = new Map<String, dynamic>();
      }
      if (data != null) {
        contact.data?.addAll(data);
      }
      contact.nknWalletAddress = data?['nknWalletAddress'];
      if (contact.nknWalletAddress == null || contact.nknWalletAddress!.isEmpty) {
        contact.nknWalletAddress = await Wallet.pubKeyToWalletAddr(getPublicKeyByClientAddr(contact.clientAddress));
      }
    }
    return contact;
  }

  @override
  String toString() {
    return 'ContactSchema{id: $id, clientAddress: $clientAddress, type: $type, createdAt: $createdAt, updatedAt: $updatedAt, avatar: $avatar, firstName: $firstName, lastName: $lastName, profileVersion: $profileVersion, profileUpdateAt: $profileUpdateAt, isTop: $isTop, deviceToken: $deviceToken, notificationOpen: $notificationOpen, options: $options, data: $data, nknWalletAddress: $nknWalletAddress}';
  }
}

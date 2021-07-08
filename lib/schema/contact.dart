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
  String type; // (required) <-> type
  String clientAddress; // (required : (ID).PubKey) <-> address
  String? nknWalletAddress; // == extraInfo[nknWalletAddress] <-> data[nknWalletAddress]
  File? avatar; // (local_path) <-> avatar
  String? firstName; // (required : name) <-> first_name
  String? lastName; // <-> last_name
  String? notes; // == extraInfo[notes] <-> data[notes]
  OptionsSchema? options; // <-> options
  Map<String, dynamic>? extraInfo; // [*]<-> data[*, avatar, firstName, notes, nknWalletAddress, ...]

  DateTime? createdTime; // <-> created_time
  DateTime? updatedTime; // <-> updated_time
  String? profileVersion; // <-> profile_version
  DateTime? profileExpiresAt; // <-> profile_expires_at(long) == update_at

  bool isTop = false; // <-> is_top
  String? deviceToken; // <-> device_token
  bool notificationOpen = false; // <-> notification_open

  ContactSchema({
    this.id,
    required this.type,
    required this.clientAddress,
    this.nknWalletAddress,
    this.firstName,
    this.lastName,
    this.notes,
    this.extraInfo,
    this.avatar,
    this.options,
    this.createdTime,
    this.updatedTime,
    this.profileVersion,
    this.profileExpiresAt,
    this.isTop = false,
    this.deviceToken,
    this.notificationOpen = false,
  }) {
    if (options == null) {
      options = OptionsSchema();
    }
  }

  static Future<ContactSchema?> createByType(String? clientAddress, String contactType) async {
    if (clientAddress == null || clientAddress.isEmpty) return null;
    String? walletAddress = await Wallet.pubKeyToWalletAddr(getPublicKeyByClientAddr(clientAddress));
    return ContactSchema(
      type: contactType,
      clientAddress: clientAddress,
      nknWalletAddress: walletAddress,
      createdTime: DateTime.now(),
      updatedTime: DateTime.now(),
      profileVersion: Uuid().v4(),
    );
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

    if (extraInfo?.isNotEmpty == true) {
      if (extraInfo!['firstName']?.toString().isNotEmpty == true) {
        displayName = extraInfo!['firstName'];
      }
      // SUPPORT:START
      else if (extraInfo!['remark_name']?.toString().isNotEmpty == true) {
        displayName = extraInfo!['remark_name'];
      } else if (extraInfo!['notes']?.toString().isNotEmpty == true) {
        displayName = extraInfo!['notes'];
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

    if (extraInfo?.toString().isNotEmpty == true) {
      if (extraInfo!['avatar']?.toString().isNotEmpty == true) {
        avatarLocalPath = extraInfo!['avatar'];
      }
      // SUPPORT:START
      else if (extraInfo!['remark_avatar']?.toString().isNotEmpty == true) {
        avatarLocalPath = extraInfo!['remark_avatar'];
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

  Future<Map<String, dynamic>> toMap() async {
    if (extraInfo == null) {
      extraInfo = new Map<String, dynamic>();
    }
    if (nknWalletAddress?.isNotEmpty == true) {
      extraInfo?['nknWalletAddress'] = nknWalletAddress;
    } else {
      extraInfo?['nknWalletAddress'] = await Wallet.pubKeyToWalletAddr(getPublicKeyByClientAddr(clientAddress));
    }
    if (notes?.isNotEmpty == true) {
      extraInfo?['notes'] = notes;
    }
    if (extraInfo?.keys.length == 0) {
      extraInfo = null;
    }

    if (options == null) {
      options = OptionsSchema();
    }

    Map<String, dynamic> map = {
      'type': type,
      'address': clientAddress,
      'avatar': Path.getLocalFile(avatar?.path),
      'first_name': firstName ?? getDefaultName(clientAddress),
      'last_name': lastName,
      'options': options != null ? jsonEncode(options!.toMap()) : null,
      'data': (extraInfo?.isNotEmpty == true) ? jsonEncode(extraInfo) : '{}',
      'created_time': createdTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'updated_time': updatedTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'profile_version': profileVersion ?? Uuid().v4(),
      'profile_expires_at': profileExpiresAt?.millisecondsSinceEpoch,
      'is_top': isTop ? 1 : 0,
      'device_token': deviceToken,
      'notification_open': notificationOpen ? 1 : 0,
    };
    return map;
  }

  static Future<ContactSchema> fromMap(Map e) async {
    var contact = ContactSchema(
      id: e['id'],
      type: e['type'] ?? ContactType.stranger,
      clientAddress: e['address'] ?? "",
      avatar: Path.getCompleteFile(e['avatar']) != null ? File(Path.getCompleteFile(e['avatar'])!) : null,
      firstName: e['first_name'] ?? getDefaultName(e['address']),
      lastName: e['last_name'],
      createdTime: e['created_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['created_time']) : null,
      updatedTime: e['updated_time'] != null ? DateTime.fromMillisecondsSinceEpoch(e['updated_time']) : null,
      profileVersion: e['profile_version'],
      profileExpiresAt: e['profile_expires_at'] != null ? DateTime.fromMillisecondsSinceEpoch(e['profile_expires_at']) : null,
      isTop: (e['is_top'] != null) && (e['is_top'] == 1) ? true : false,
      deviceToken: e['device_token'],
      notificationOpen: (e['notification_open'] != null && e['notification_open'].toString() == '1') ? true : false,
    );

    if (e['data']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? data = jsonFormat(e['data']);

      if (contact.extraInfo == null) {
        contact.extraInfo = new Map<String, dynamic>();
      }
      if (data != null) {
        contact.extraInfo?.addAll(data);
      }
      contact.nknWalletAddress = data?['nknWalletAddress'];
      if (contact.nknWalletAddress == null || contact.nknWalletAddress!.isEmpty) {
        contact.nknWalletAddress = await Wallet.pubKeyToWalletAddr(getPublicKeyByClientAddr(contact.clientAddress));
      }
      contact.notes = data?['notes'];
    }

    if (e['options']?.toString().isNotEmpty == true) {
      Map<String, dynamic>? options = jsonFormat(e['options']);
      contact.options = OptionsSchema.fromMap(options ?? Map());
    }
    if (contact.options == null) {
      contact.options = OptionsSchema();
    }
    return contact;
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

  @override
  String toString() {
    return 'ContactSchema{id: $id, type: $type, clientAddress: $clientAddress, nknWalletAddress: $nknWalletAddress, firstName: $firstName, lastName: $lastName, notes: $notes, extraInfo: $extraInfo, avatar: $avatar, options: $options, createdTime: $createdTime, updatedTime: $updatedTime, profileVersion: $profileVersion, profileExpiresAt: $profileExpiresAt, isTop: $isTop, deviceToken: $deviceToken, notificationOpen: $notificationOpen}';
  }
}

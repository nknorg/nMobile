import 'dart:convert';
import 'dart:io';
import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/path.dart';

import 'option.dart';

class SourceProfile {
  String firstName;
  String lastName;
  File avatar;

  SourceProfile({this.firstName, this.lastName, this.avatar});

  String get name {
    return '${firstName ?? ''} ${lastName ?? ''}'.trim();
  }

  String toJson() {
    Map<String, dynamic> map = {};
    if (firstName != null) map['firstName'] = firstName;
    if (lastName != null) map['lastName'] = lastName;
    if (avatar != null) map['avatar'] = base64Encode(avatar.readAsBytesSync());
    return jsonEncode(map);
  }
}

class ContactSchema {
  int id;
  String type;
  String clientAddress;
  String nknWalletAddress;
  String firstName;
  String lastName;
  String notes;
  Map extraInfo;

  File avatar;
  OptionsSchema options;
  DateTime createdTime;
  DateTime updatedTime;
  SourceProfile sourceProfile;
  String profileVersion;
  DateTime profileExpiresAt;

  // deviceToken
  String deviceToken;

  bool isTop;

  ContactSchema({
    this.id,
    this.type,
    this.clientAddress,
    this.nknWalletAddress,
    this.firstName,
    this.lastName,
    this.notes,
    this.avatar,
    this.options,
    this.createdTime,
    this.updatedTime,
    this.profileVersion,
    this.profileExpiresAt,
    this.deviceToken,
    this.isTop = false,
  }) {
    if (options == null) {
      options = OptionsSchema();
    }
  }

  Map toEntity() {
    if (extraInfo == null) {
      extraInfo = new Map<String, dynamic>();
    }
    if (nknWalletAddress != null) extraInfo['nknWalletAddress'] = nknWalletAddress;
    if (notes != null) extraInfo['notes'] = notes;
    if (extraInfo.keys.length == 0) extraInfo = null;

    DateTime now = DateTime.now();
    options = OptionsSchema();
    Map<String, dynamic> map = {
      'type': type,
      'address': clientAddress,
      'first_name': firstName,
      'last_name': lastName,
      'data': extraInfo != null ? jsonEncode(extraInfo) : '{}',
      'options': options?.toJson(),
      'avatar': avatar != null ? getLocalContactPath(chat.id, avatar.path) : null,
      'created_time': createdTime?.millisecondsSinceEpoch ?? now,
      'updated_time': updatedTime?.millisecondsSinceEpoch,
      'profile_version': profileVersion,
      'profile_expires_at': profileExpiresAt?.millisecondsSinceEpoch,
      'is_top': isTop ? 1 : 0,
    };

    return map;
  }

  bool get isMe {
    if (type == ContactType.me) {
      return true;
    } else {
      return false;
    }
  }

  String get getDisplayName {
    String showName = '';
    if (firstName != null && firstName.length > 0) {
      showName = firstName;
      if (showName.length > 0) {
        return showName;
      }
    }
    if (sourceProfile != null) {
      if (sourceProfile.firstName != null && sourceProfile.firstName.length > 0) {
        showName = sourceProfile.firstName;
        return showName;
      }
    }
    var index = clientAddress.lastIndexOf('.');
    if (index < 0) {
      showName = clientAddress.substring(0, 6);
    } else {
      showName = clientAddress.substring(0, index + 7);
    }
    return showName;
  }

  String get getDisplayAvatarPath {
    String avatarPath = '';
    if (avatar?.path != null) {
      avatarPath = avatar.path;
    }
    if (sourceProfile != null) {
      if (sourceProfile.avatar != null && sourceProfile.avatar.path.length > 0) {
        avatarPath = sourceProfile.avatar.path;
      }
    }
    return avatarPath;
  }
}

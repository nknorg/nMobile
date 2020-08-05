/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'package:flutter/services.dart';
import 'package:nmobile/utils/log_tag.dart';

class CommonNative {
  static const String CHANNEL = "org.nkn.nmobile/native/common";
  static final _platform = MethodChannel(CHANNEL);
  static final _log = LOG('CommonNative'.tag());

  static Future<bool> isActive() async {
    try {
      return await _platform.invokeMethod('isActive');
    } catch (e) {
      _log.e('isActive', e);
    }
    return false;
  }

  static Future<bool> androidBackToDesktop() async {
    try {
      await _platform.invokeMethod('backDesktop');
    } catch (e) {
      _log.e('androidBackToDesktop', e);
    }
    return false;
  }
}

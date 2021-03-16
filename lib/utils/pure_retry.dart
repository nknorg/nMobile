/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/utils/log_tag.dart';

/// @author Chenai
/// @version 1.0, 09/07/2020
void retryForceful(
    {@required int delayMillis,
    int times = 8,
    int increase = 0,
    int from = 8,
    @required bool action(int times)}) async {
  if (!action(times) && times > 1) {
    Timer(
        Duration(
            milliseconds: (times - 1) < from
                ? delayMillis + increase * (from - (times - 1))
                : delayMillis), () {
      retryForceful(
          delayMillis: delayMillis,
          times: times - 1,
          increase: increase,
          from: from,
          action: action);
    });
  }
}

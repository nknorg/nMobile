/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:nmobile/helpers/global.dart';

/// @author Wei.Chou
/// @version 1.0, 07/02/2020
@protected
mixin Tag {
  String get tag => _tagInner(23, 3);

  String get unique => _tagInner(32, 5);

  String _tagInner(int length, int lenHashCode) {
    final String name = this.runtimeType.toString() +
        '@' +
        hashCode.toString().substring(0, lenHashCode);
    if (name.length > length) {
      return name.substring(name.length - length);
    } else
      return name.tag(length);
  }
}

extension StringTag on String {
  String tag([int width = 23]) => this.padLeft(width, '.');
}

class LOG {
  static final _logger = Logger(printer: PrettyPrinter());

  final bool usePrint;
  final String tag;

  const LOG(this.tag, {this.usePrint: true});

  void i(dynamic message) {
    if (!Global.isRelease) {
      final msg = '$tag |<I>| ${message?.toString()}';
      if (usePrint)
        print(msg);
      else
        _logger.i(msg);
    }
  }

  void d(dynamic message) {
    if (!Global.isRelease) {
      final msg = '$tag |<D>| ${message?.toString()}';
      if (usePrint)
        print(msg);
      else
        _logger.d(msg);
    }
  }

  void w(dynamic message) {
    /*if (!Global.isRelease)*/
    final msg = '$tag |<W>| ${message?.toString()}';
    /*if (usePrint)
      print(msg);
    else*/
    _logger.w(msg);
  }

  void e(dynamic message, dynamic error) {
    /*if (!Global.isRelease)*/
    final msg =
        '$tag |<E>| ${message?.toString()} |###| error: ${error?.toString()}';
    /*if (usePrint)
      print(msg);
    else*/
    _logger.e(msg);
  }
}

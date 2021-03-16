import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/schemas/options.dart';

class TopicSchema {
  static Widget xd({
    File avatar,
    @required String topicName,
    @required double size,
    @required OptionsSchema options,
    Widget bottomRight,
  }) {
    LabelType fontType = LabelType.h4;
    if (size > 60) {
      fontType = LabelType.h1;
    } else if (size > 50) {
      fontType = LabelType.h2;
    } else if (size > 40) {
      fontType = LabelType.h3;
    } else if (size > 30) {
      fontType = LabelType.h4;
    }
    if (avatar == null) {
      var wid = <Widget>[
        Material(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          color: Color(options.backgroundColor),
          child: Container(
            alignment: Alignment.center,
            width: size,
            height: size,
            child: Label(
              topicName.substring(0, min(2, topicName.length)).toUpperCase(),
              type: fontType,
              color: Color(options.color),
            ),
          ),
        ),
      ];

      if (bottomRight != null) {
        wid.add(
          Positioned(
            bottom: 0,
            right: 0,
            child: bottomRight,
          ),
        );
      }
      return Stack(
        children: wid,
      );
    } else {
      return SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6.0),
          child: Container(
            decoration:
                BoxDecoration(image: DecorationImage(image: FileImage(avatar))),
          ),
        ),
      );
    }
  }
}

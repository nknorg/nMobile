import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/utils/asset.dart';

class TopicAvatar extends BaseStateFulWidget {
  final TopicSchema topic;
  final double? radius;
  final bool? placeHolder;

  TopicAvatar({
    required this.topic,
    this.radius,
    this.placeHolder = false,
  });

  @override
  _TopicAvatarState createState() => _TopicAvatarState();
}

class _TopicAvatarState extends BaseStateFulWidgetState<TopicAvatar> {
  File? _avatarFile;

  @override
  void onRefreshArguments() {
    _checkAvatarFileExists();
  }

  _checkAvatarFileExists() async {
    File? avatarFile = await widget.topic.displayAvatarFile;
    if (_avatarFile?.path != avatarFile?.path) {
      setState(() {
        _avatarFile = avatarFile;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double radius = this.widget.radius ?? 24;
    String name = widget.topic.topicName;

    if (_avatarFile != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(this._avatarFile!),
      );
    }
    if (widget.placeHolder == null || !widget.placeHolder!) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: widget.topic.options?.avatarBgColor ?? application.theme.primaryColor.withAlpha(19),
        child: Label(
          name.length > 2 ? name.substring(0, 2).toUpperCase() : name,
          color: widget.topic.options?.avatarNameColor ?? application.theme.fontLightColor,
          type: LabelType.h3,
          fontSize: radius / 3 * 2,
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: application.theme.backgroundColor2,
      child: Asset.iconSvg('user', color: application.theme.fontColor2),
    );
  }
}

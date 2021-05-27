import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/utils/asset.dart';

class TopicAvatar extends StatefulWidget {
  final TopicSchema topic;
  final double? radius;
  final bool? placeHolder;

  TopicAvatar({
    required Key key,
    required this.topic,
    this.radius,
    this.placeHolder = false,
  }) : super(key: key);

  @override
  _TopicAvatarState createState() => _TopicAvatarState();
}

class _TopicAvatarState extends State<TopicAvatar> {
  bool _avatarFileExits = false;

  @override
  void initState() {
    super.initState();
    _checkAvatarFileExists();
  }

  _checkAvatarFileExists() async {
    bool exists = await widget.topic.avatar?.exists() ?? false;
    if (_avatarFileExits != exists) {
      setState(() {
        _avatarFileExits = exists;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double radius = this.widget.radius ?? 24;
    String name = widget.topic.topicName ?? "";

    if (_avatarFileExits) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(widget.topic.avatar!),
      );
    }
    if (widget.placeHolder == null || !widget.placeHolder!) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: widget.topic.options?.backgroundColor ?? application.theme.primaryColor.withAlpha(19),
        child: Label(
          name.length > 2 ? name.substring(0, 2).toUpperCase() : name,
          color: widget.topic.options?.color ?? application.theme.fontLightColor,
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

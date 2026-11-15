import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/plain_circle_avatar.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/utils/asset.dart';

class TopicAvatar extends BaseStateFulWidget {
  final TopicSchema topic;
  final double radius;
  final bool placeHolder;

  TopicAvatar({
    required this.topic,
    this.radius = 24,
    this.placeHolder = false,
  });

  @override
  _TopicAvatarState createState() => _TopicAvatarState();
}

class _TopicAvatarState extends BaseStateFulWidgetState<TopicAvatar> {
  @override
  void onRefreshArguments() {}

  @override
  Widget build(BuildContext context) {
    double radius = this.widget.radius;
    String name = widget.topic.topicName;
    String? path = widget.topic.displayAvatarPath;
    Widget fallback;
    if (widget.placeHolder == true) {
      fallback = CircleAvatar(
        radius: radius,
        backgroundColor: application.theme.backgroundColor2,
        child: Asset.iconSvg('user', color: application.theme.fontColor2),
      );
    } else {
      fallback = CircleAvatar(
        radius: radius,
        backgroundColor: widget.topic.options.avatarBgColor ?? application.theme.primaryColor.withAlpha(19),
        child: Label(
          name.length > 2 ? name.substring(0, 2).toUpperCase() : name,
          color: widget.topic.options.avatarNameColor ?? application.theme.fontLightColor,
          type: LabelType.h3,
          fontSize: radius / 3 * 2,
        ),
      );
    }
    if (path == null || path.isEmpty) return fallback;
    return PlainCircleAvatar(path: path, radius: radius, fallback: fallback);
  }
}

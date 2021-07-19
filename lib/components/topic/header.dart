import 'package:flutter/material.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/topic.dart';
import 'package:nmobile/utils/asset.dart';

import 'avatar.dart';

class TopicHeader extends StatelessWidget {
  final TopicSchema topic;
  final Widget body;
  final double avatarRadius;
  final bool dark;
  final GestureTapCallback? onTap;

  TopicHeader({
    required this.topic,
    required this.body,
    this.avatarRadius = 24,
    this.dark = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String name = this.topic.topicShort;
    return GestureDetector(
      onTap: () {
        if (this.onTap != null) this.onTap!();
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: TopicAvatar(
              topic: this.topic,
              radius: this.avatarRadius,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    this.topic.isPrivate
                        ? Asset.iconSvg(
                            'lock',
                            width: 18,
                            color: Colors.white,
                          )
                        : SizedBox.shrink(),
                    Expanded(
                      child: Label(
                        name,
                        type: LabelType.h3,
                        fontWeight: FontWeight.bold,
                        dark: this.dark,
                      ),
                    ),
                  ],
                ),
                this.body,
              ],
            ),
          )
        ],
      ),
    );
  }
}

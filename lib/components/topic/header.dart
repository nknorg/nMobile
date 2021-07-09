import 'package:flutter/material.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/topic.dart';

import 'avatar.dart';

class TopicHeader extends StatelessWidget {
  final TopicSchema topic;
  final Widget body;
  final GestureTapCallback? onTap;
  final bool syncData;

  TopicHeader({
    required this.topic,
    required this.body,
    this.onTap,
    this.syncData = true,
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
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Label(name, type: LabelType.h3, dark: true),
                this.body,
              ],
            ),
          )
        ],
      ),
    );
  }
}

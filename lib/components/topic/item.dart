import 'package:flutter/material.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/topic.dart';

import 'avatar.dart';

class TopicItem extends StatefulWidget {
  final TopicSchema topic;
  final Widget body;
  final String bodyTitle;
  final String bodyDesc;
  final GestureTapCallback onTap;
  final bool onTapWave;
  final Color bgColor;
  final BorderRadius radius;
  final EdgeInsetsGeometry padding;
  final Widget tail;

  TopicItem({
    this.topic,
    this.body,
    this.bodyTitle,
    this.bodyDesc,
    this.onTap,
    this.onTapWave = true,
    this.bgColor,
    this.radius,
    this.padding,
    this.tail,
  });

  @override
  _TopicItemState createState() => _TopicItemState();
}

class _TopicItemState extends State<TopicItem> {
  @override
  Widget build(BuildContext context) {
    return widget.onTap != null
        ? widget.onTapWave
            ? Material(
                color: widget.bgColor,
                elevation: 0,
                borderRadius: widget.radius,
                child: InkWell(
                  borderRadius: widget.radius,
                  onTap: widget.onTap,
                  child: _getItemBody(),
                ),
              )
            : InkWell(
                borderRadius: widget.radius,
                onTap: widget.onTap,
                child: _getItemBody(),
              )
        : _getItemBody();
  }

  Widget _getItemBody() {
    return Container(
      decoration: BoxDecoration(
        color: (widget.onTap != null && widget.onTapWave) ? null : widget.bgColor,
        borderRadius: widget.radius,
      ),
      padding: widget.padding ?? EdgeInsets.only(right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: TopicAvatar(
              key: ValueKey(widget.topic.avatar?.path ?? ''),
              topic: widget.topic,
            ),
          ),
          Expanded(
            flex: 1,
            child: widget.body != null
                ? widget.body
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Label(
                        widget.bodyTitle ?? "",
                        type: LabelType.h3,
                        fontWeight: FontWeight.bold,
                      ),
                      SizedBox(height: 6),
                      Label(
                        widget.bodyDesc ?? "",
                        maxLines: 1,
                        type: LabelType.bodyRegular,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
          ),
          widget.tail != null ? widget.tail : SizedBox(),
        ],
      ),
    );
  }
}

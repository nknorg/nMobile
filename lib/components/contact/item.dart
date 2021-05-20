import 'package:flutter/material.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';

import 'avatar.dart';

class ContactItem extends StatefulWidget {
  final ContactSchema contact;
  final Widget body;
  final String bodyTitle;
  final String bodyDesc;
  final GestureTapCallback onTap;
  final bool onTapWave;
  final Color bgColor;
  final BorderRadius radius;
  final EdgeInsetsGeometry padding;
  final Widget tail;

  ContactItem({
    this.contact,
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
  _ContactItemState createState() => _ContactItemState();
}

class _ContactItemState extends State<ContactItem> {
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
      padding: widget.padding ?? EdgeInsets.only(left: 16, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: ContactAvatar(
              contact: widget.contact,
            ),
          ),
          widget.body != null
              ? Expanded(
                  flex: 1,
                  child: widget.body,
                )
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
          widget.tail != null ? widget.tail : SizedBox(),
        ],
      ),
    );
  }
}

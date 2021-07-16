import 'package:flutter/material.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/schema/contact.dart';

import 'avatar.dart';

class ContactItem extends StatelessWidget {
  final ContactSchema contact;
  final Widget? body;
  final String? bodyTitle;
  final String? bodyDesc;
  final GestureTapCallback? onTap;
  final bool onTapWave;
  final Color? bgColor;
  final BorderRadius? radius;
  final EdgeInsetsGeometry? padding;
  final Widget? tail;

  ContactItem({
    required this.contact,
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
  Widget build(BuildContext context) {
    return this.onTap != null
        ? this.onTapWave
            ? Material(
                color: this.bgColor,
                elevation: 0,
                borderRadius: this.radius,
                child: InkWell(
                  borderRadius: this.radius,
                  onTap: this.onTap,
                  child: _getItemBody(),
                ),
              )
            : InkWell(
                borderRadius: this.radius,
                onTap: this.onTap,
                child: _getItemBody(),
              )
        : _getItemBody();
  }

  Widget _getItemBody() {
    return Container(
      decoration: BoxDecoration(
        color: (this.onTap != null && this.onTapWave) ? null : this.bgColor,
        borderRadius: this.radius,
      ),
      padding: this.padding ?? EdgeInsets.only(right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: ContactAvatar(
              contact: this.contact,
            ),
          ),
          Expanded(
            child: this.body != null
                ? this.body!
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Label(
                        this.bodyTitle ?? "",
                        type: LabelType.h3,
                        fontWeight: FontWeight.bold,
                      ),
                      SizedBox(height: 6),
                      Label(
                        this.bodyDesc ?? "",
                        maxLines: 1,
                        type: LabelType.bodyRegular,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
          ),
          this.tail != null ? this.tail! : SizedBox(),
        ],
      ),
    );
  }
}

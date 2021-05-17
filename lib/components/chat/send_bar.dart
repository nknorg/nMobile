import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button_icon.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/asset.dart';
import 'package:nmobile/theme/theme.dart';

class ChatSendBar extends StatefulWidget {
  final VoidCallback onMenuPressed;
  ChatSendBar({this.onMenuPressed});

  @override
  _ChatSendBarState createState() => _ChatSendBarState();
}

class _ChatSendBarState extends State<ChatSendBar> {
  FocusNode _sendFocusNode = FocusNode();
  TextEditingController _sendController = TextEditingController();
  bool _canSend = false;

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    SkinTheme _theme = application.theme;
    return Container(
      constraints: BoxConstraints(minHeight: 70, maxHeight: 160),
      child: Flex(
        direction: Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            flex: 0,
            child: Container(
              margin: const EdgeInsets.only(left: 0, right: 0, top: 15, bottom: 15),
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: ButtonIcon(
                width: 50,
                height: 50,
                icon: Asset.iconSvg(
                  'grid',
                  width: 24,
                  color: _theme.primaryColor,
                ),
                onPressed: widget.onMenuPressed,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.only(left: 0, right: 0, top: 15, bottom: 15),
              decoration: BoxDecoration(
                color: _theme.backgroundColor2,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: Flex(
                direction: Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    flex: 1,
                    child: TextField(
                      maxLines: 5,
                      minLines: 1,
                      controller: _sendController,
                      focusNode: _sendFocusNode,
                      textInputAction: TextInputAction.newline,
                      onChanged: (val) {
                        if (mounted) {
                          setState(() {
                            _canSend = val.isNotEmpty;
                          });
                        }
                      },
                      style: TextStyle(fontSize: 14, height: 1.4),
                      decoration: InputDecoration(
                        hintText: S.of(context).type_a_message,
                        hintStyle: TextStyle(color: _theme.fontColor2),
                        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        border: UnderlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                          borderSide: const BorderSide(width: 0, style: BorderStyle.none),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 0,
            child: Container(
              margin: const EdgeInsets.only(left: 0, right: 0, top: 15, bottom: 15),
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: ButtonIcon(
                width: 50,
                height: 50,
                icon: Asset.iconSvg(
                  'send',
                  width: 24,
                  color: _canSend ? _theme.primaryColor : _theme.fontColor2,
                ),
                onPressed: () {
                  // _send(); TODO
                },
              ),
            ),
          ),
          // _voiceAndSendWidget(),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button_icon.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/asset.dart';

class ChatSendBar extends BaseStateFulWidget {
  final String targetId;
  final VoidCallback? onMenuPressed;
  final Function(String)? onSendPress;

  ChatSendBar({required this.targetId, this.onMenuPressed, this.onSendPress});

  @override
  _ChatSendBarState createState() => _ChatSendBarState();
}

class _ChatSendBarState extends BaseStateFulWidgetState<ChatSendBar> {
  FocusNode _sendFocusNode = FocusNode();
  TextEditingController _sendController = TextEditingController();
  bool _canSend = false;
  late String? _draft;

  @override
  void initState() {
    super.initState();
    _draft = memoryCache.getDraft(widget.targetId);
    if (_draft?.isNotEmpty == true) {
      _sendController.text = _draft!;
      _canSend = true;
    }
  }

  @override
  void onRefreshArguments() {}

  @override
  Widget build(BuildContext context) {
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
                        String draft = _sendController.text;
                        if (draft.isNotEmpty) {
                          memoryCache.setDraft(widget.targetId, draft);
                        } else {
                          memoryCache.removeDraft(widget.targetId);
                        }

                        setState(() {
                          _canSend = val.isNotEmpty;
                        });
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
                onPressed: () async {
                  memoryCache.removeDraft(widget.targetId);
                  // TODO:GG refactor
                  String content = _sendController.text;
                  if (content.isEmpty) return;
                  _canSend = false;
                  var result = await widget.onSendPress?.call(content);
                  if (result != null) {
                    _sendController.clear();
                  }
                  _canSend = true;
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button_icon.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/asset.dart';

class ChatSendBar extends BaseStateFulWidget {
  static const String ChangeTypeReplace = "replace";
  static const String ChangeTypeAppend = "append";

  final String targetId;
  final VoidCallback? onMenuPressed;
  final Function(String)? onSendPress;
  final Stream<Map<String, dynamic>>? onChangeStream;

  ChatSendBar({
    Key? key,
    required this.targetId,
    this.onMenuPressed,
    this.onSendPress,
    this.onChangeStream,
  }) : super(key: key);

  @override
  _ChatSendBarState createState() => _ChatSendBarState();
}

class _ChatSendBarState extends BaseStateFulWidgetState<ChatSendBar> {
  StreamSubscription? _onChangeSubscription;
  TextEditingController _sendController = TextEditingController();
  FocusNode _sendFocusNode = FocusNode();

  bool _canSend = false;
  String? _draft;

  @override
  void initState() {
    super.initState();
    // onChange
    _onChangeSubscription = widget.onChangeStream?.listen((event) {
      String? type = event["type"];
      if (type == null || type.isEmpty) return;
      if (type == ChatSendBar.ChangeTypeReplace) {
        _sendController.text = event["content"] ?? "";
      } else if (type == ChatSendBar.ChangeTypeAppend) {
        _sendController.text += event["content"] ?? "";
      }
      setState(() {
        _canSend = _sendController.text.isNotEmpty;
      });
    });
    // draft
    _draft = memoryCache.getDraft(widget.targetId);
    if (_draft?.isNotEmpty == true) {
      _sendController.text = _draft!;
      _canSend = true;
    }
  }

  @override
  void onRefreshArguments() {}

  @override
  void dispose() {
    _onChangeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SkinTheme _theme = application.theme;

    return Container(
      constraints: BoxConstraints(minHeight: 70, maxHeight: 160),
      child: Row(
        children: <Widget>[
          ButtonIcon(
            width: 66,
            height: 70,
            icon: Asset.iconSvg(
              'grid',
              width: 24,
              color: _theme.primaryColor,
            ),
            onPressed: widget.onMenuPressed,
          ),
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: _theme.backgroundColor2,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    flex: 1,
                    child: TextField(
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
                    ),
                  ),
                ],
              ),
            ),
          ),
          ButtonIcon(
            width: 66,
            height: 70,
            icon: Asset.iconSvg(
              'send',
              width: 24,
              color: _canSend ? _theme.primaryColor : _theme.fontColor2,
            ),
            onPressed: () async {
              String content = _sendController.text;
              if (content.isEmpty) return;
              memoryCache.removeDraft(widget.targetId);
              _sendController.clear();
              _canSend = false;
              await widget.onSendPress?.call(content);
            },
          ),
          // _voiceAndSendWidget(),
        ],
      ),
    );
  }
}

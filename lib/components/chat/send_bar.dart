import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button_icon.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/asset.dart';

class ChatSendBar extends BaseStateFulWidget {
  static const String ChangeTypeReplace = "replace";
  static const String ChangeTypeAppend = "append";

  final String? targetId;
  final VoidCallback? onMenuPressed;
  final Function(String)? onSendPress;
  final Function(bool, bool, int)? onRecordTap;
  final Stream<Map<String, dynamic>>? onChangeStream;

  ChatSendBar({
    Key? key,
    required this.targetId,
    this.onMenuPressed,
    this.onSendPress,
    this.onRecordTap,
    this.onChangeStream,
  }) : super(key: key);

  @override
  _ChatSendBarState createState() => _ChatSendBarState();
}

class _ChatSendBarState extends BaseStateFulWidgetState<ChatSendBar> {
  StreamSubscription? _onChangeSubscription;
  StreamSubscription? _onRecordProgressSubscription;
  TextEditingController _sendController = TextEditingController();
  FocusNode _sendFocusNode = FocusNode();

  String? _draft;
  bool _canSend = false;

  bool _audioRecordVisible = false;
  int _audioRecordDurationMs = 0;

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
    // record
    _onRecordProgressSubscription = audioHelper.onRecordProgressStream.listen((event) {
      String? recordId = event["id"];
      Duration? duration = event["duration"];
      // double? volume = event["volume"];
      if (recordId == null || recordId != widget.targetId || duration == null) {
        if (_audioRecordDurationMs != 0) {
          setState(() {
            _audioRecordDurationMs = 0;
          });
        }
        return;
      }
      if (duration.inMilliseconds == _audioRecordDurationMs) return;
      this.setState(() {
        _audioRecordDurationMs = duration.inMilliseconds;
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
    _onRecordProgressSubscription?.cancel();
    _onChangeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SkinTheme _theme = application.theme;

    Color recordColor = (_audioRecordDurationMs % 1000) <= 500 ? Colors.red : Colors.transparent;

    return Container(
      constraints: BoxConstraints(minHeight: 70, maxHeight: 160),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 1,
            child: !_audioRecordVisible
                ? Row(
                    children: [
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
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: Icon(FontAwesomeIcons.microphone, size: 24, color: recordColor),
                      ),
                      Container(
                        child: Label("recordLength", type: LabelType.bodyRegular, fontWeight: FontWeight.normal, color: Colors.red),
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          color: Colors.red[100],
                          child: SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
          ),
          _canSend
              ? ButtonIcon(
                  width: 66,
                  height: 70,
                  icon: Asset.iconSvg(
                    'send',
                    width: 24,
                    color: _canSend ? _theme.primaryColor : _theme.fontColor2,
                  ),
                  onPressed: () {
                    String content = _sendController.text;
                    if (content.isEmpty) return;
                    _sendController.clear();
                    setState(() {
                      _canSend = false;
                    });
                    memoryCache.removeDraft(widget.targetId);
                    widget.onSendPress?.call(content); // await
                  },
                )
              : GestureDetector(
                  onTapDown: (TapDownDetails details) {
                    _setAudioRecordVisible(true, false);
                  },
                  onTapUp: (TapUpDetails details) {
                    _setAudioRecordVisible(false, true); // TODO:GG touchArea
                  },
                  onTapCancel: () {
                    _setAudioRecordVisible(false, false); // TODO:GG touchArea
                  },
                  child: Container(
                    width: 66,
                    height: 70,
                    child: UnconstrainedBox(
                      child: Asset.iconSvg(
                        'microphone',
                        width: 24,
                        color: !_canSend ? _theme.primaryColor : _theme.fontColor2,
                      ),
                    ),
                  ),
                ),
          // _voiceAndSendWidget(),
        ],
      ),
    );
  }

  _setAudioRecordVisible(bool visible, bool complete) {
    if (visible == _audioRecordVisible) return;
    this.setState(() {
      _audioRecordVisible = visible;
    });
    widget.onRecordTap?.call(visible, complete, _audioRecordDurationMs); // await
  }
}

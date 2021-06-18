import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
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
  static const double ActionWidth = 66;
  static const double ActionHeight = 70;

  StreamSubscription? _onChangeSubscription;
  StreamSubscription? _onRecordProgressSubscription;
  TextEditingController _sendController = TextEditingController();
  FocusNode _sendFocusNode = FocusNode();

  double? screenWidth;
  String? _draft;
  bool _canSendText = false;

  bool _audioRecordVisible = false;
  bool _audioLockedMode = false;
  int _audioRecordDurationMs = 0;

  ColorTween _audioBgColorTween = ColorTween(begin: Colors.transparent, end: Colors.red);
  ColorTween _audioTextColorTween = ColorTween(begin: Colors.red, end: Colors.white);
  double _audioDragPercent = 0;

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
        _canSendText = _sendController.text.isNotEmpty;
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
      _canSendText = true;
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
    if (screenWidth == null) screenWidth = MediaQuery.of(context).size.width;
    SkinTheme _theme = application.theme;

    Color? recordWidgetColor = _audioTextColorTween.transform(_audioDragPercent);
    Color? volumeColor = (_audioRecordDurationMs % 1000) <= 500 ? recordWidgetColor : Colors.transparent;

    Duration recordDuration = Duration(milliseconds: _audioRecordDurationMs);
    String recordMin = "${recordDuration.inMinutes < 10 ? 0 : ""}${recordDuration.inMinutes}";
    String recordSec = "${recordDuration.inSeconds < 10 ? 0 : ""}${recordDuration.inSeconds}";
    String recordDurationText = "$recordMin:$recordSec";

    return Container(
      constraints: BoxConstraints(minHeight: 70, maxHeight: 160),
      child: GestureDetector(
        onTapDown: (TapDownDetails details) {
          this._onGesture(
            details.localPosition.dx,
            details.localPosition.dy,
            menuToggle: () => widget.onMenuPressed?.call(),
            sendText: () => _onSendText(),
            recordStart: () => _setAudioRecordVisible(true, false),
            recordSuccess: () => _setAudioRecordVisible(false, true),
            recordCancel: () => _setAudioRecordVisible(false, false),
          );
        },
        onLongPressStart: (LongPressStartDetails details) {
          this._onGesture(
            details.localPosition.dx,
            details.localPosition.dy,
            recordStart: () => _setAudioRecordVisible(true, false),
            recordSuccess: () => _setAudioRecordVisible(false, true),
            recordCancel: () => _setAudioRecordVisible(false, false),
          );
        },
        onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) {
          double offsetX = details.localPosition.dx;
          double offsetY = details.localPosition.dy;
          if (0 <= offsetY && offsetY <= ActionHeight) {
            if (ActionWidth * 1.5 < offsetX && offsetX < (screenWidth! - ActionWidth * 1.5)) {
              double touchWidth = (screenWidth! - ActionWidth * 3);
              double percent = 1 - (((offsetX - ActionWidth * 1.5) - (touchWidth / 2)) / (touchWidth / 2)).abs();
              if (_audioDragPercent != percent) {
                setState(() {
                  _audioDragPercent = percent;
                });
              }
            } else {
              if (_audioDragPercent != 0) {
                setState(() {
                  _audioDragPercent = 0;
                });
              }
            }
          } else {
            if (_audioDragPercent != 0) {
              setState(() {
                _audioDragPercent = 0;
              });
            }
            // TODO:GG 往上移lock剪头跟随 窝草居然可以溢出屏幕
          }
        },
        onLongPressEnd: (LongPressEndDetails details) {
          this._onGesture(
            details.localPosition.dx,
            details.localPosition.dy,
            recordStart: () => _setAudioRecordVisible(true, false),
            recordSuccess: () => _setAudioRecordVisible(false, true),
            recordCancel: () => _setAudioRecordVisible(false, false),
          );
        },
        child: Container(
          height: ActionHeight,
          color: _audioBgColorTween.transform(_audioDragPercent),
          child: Row(
            children: <Widget>[
              Expanded(
                flex: 1,
                child: !_audioRecordVisible
                    ? Row(
                        children: [
                          SizedBox(
                            width: ActionWidth,
                            height: ActionHeight,
                            child: UnconstrainedBox(
                              child: Asset.iconSvg(
                                'grid',
                                width: 24,
                                color: _theme.primaryColor,
                              ),
                            ),
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
                                          _canSendText = val.isNotEmpty;
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
                          SizedBox(width: 16),
                          Icon(FontAwesomeIcons.microphone, size: 24, color: volumeColor),
                          SizedBox(width: 8),
                          Container(
                            child: Label(
                              recordDurationText,
                              type: LabelType.bodyRegular,
                              fontWeight: FontWeight.normal,
                              color: recordWidgetColor,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: Container(
                              height: ActionHeight,
                              child: Center(
                                child: Label(
                                  _audioLockedMode ? S.of(context).cancel : (_audioDragPercent != 0 ? "松开取消" : S.of(context).slide_to_cancel), // TODO:GG locale record cancel
                                  color: recordWidgetColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              _canSendText
                  ? SizedBox(
                      width: ActionWidth,
                      height: ActionHeight,
                      child: UnconstrainedBox(
                        child: Asset.iconSvg(
                          'send',
                          width: 24,
                          color: _canSendText ? _theme.primaryColor : _theme.fontColor2,
                        ),
                      ),
                    )
                  : (_audioLockedMode
                      ? Label(
                          S.of(context).send,
                          type: LabelType.bodyLarge,
                          fontWeight: FontWeight.normal,
                          color: _theme.primaryColor,
                          textAlign: TextAlign.center,
                        )
                      : SizedBox(
                          width: ActionWidth,
                          height: ActionHeight,
                          child: UnconstrainedBox(
                            child: Asset.iconSvg(
                              'microphone',
                              width: 24,
                              color: !_canSendText ? _theme.primaryColor : _theme.fontColor2,
                            ),
                          ),
                        )),
              // _voiceAndSendWidget(),
            ],
          ),
        ),
      ),
    );
  }

  _onGesture(
    double offsetX,
    double offsetY, {
    Function? menuToggle,
    Function? sendText,
    Function? recordStart,
    Function? recordSuccess,
    Function? recordCancel,
  }) {
    if (0 <= offsetY && offsetY <= ActionHeight) {
      if (0 <= offsetX && offsetX <= ActionWidth) {
        if (!_audioRecordVisible) {
          // menu toggle
          menuToggle?.call();
        } else {
          // record info
        }
      } else if (ActionWidth * 1.5 < offsetX && offsetX < (screenWidth! - ActionWidth * 1.5)) {
        if (!_audioRecordVisible) {
          // text editing
        } else {
          // record cancel
          Toast.show("录音取消");
          recordCancel?.call();
        }
      } else if ((screenWidth! - ActionWidth) <= offsetX && offsetX <= screenWidth!) {
        if (_canSendText) {
          // text send
          sendText?.call();
        } else {
          if (!_audioRecordVisible) {
            // record start
            Toast.show("录音开始");
            recordStart?.call();
          } else {
            Toast.show("录音成功");
            recordSuccess?.call();
          }
        }
      }
    } else {
      // TODO:GG 上面松手lock
      if (false) {
        // setState(() {
        //   _audioLockedMode = true;
        // });
      } else {
        // record cancel
        Toast.show("录音取消");
        recordCancel?.call();
      }
    }
  }

  _onSendText() {
    String content = _sendController.text;
    if (content.isEmpty) return;
    _sendController.clear();
    setState(() {
      _canSendText = false;
    });
    memoryCache.removeDraft(widget.targetId);
    widget.onSendPress?.call(content); // await
  }

  _setAudioRecordVisible(bool visible, bool complete) {
    if (visible == _audioRecordVisible) return;
    this.setState(() {
      _audioRecordVisible = visible;
      _audioRecordDurationMs = visible ? 0 : _audioRecordDurationMs;
      _audioLockedMode = visible ? _audioLockedMode : false;
      _audioDragPercent = visible ? _audioDragPercent : 0;
    });
    widget.onRecordTap?.call(visible, complete, _audioRecordDurationMs); // await
  }
}

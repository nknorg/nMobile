import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/helpers/audio.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/asset.dart';

class ChatSendBar extends BaseStateFulWidget {
  static const String ChangeTypeReplace = "replace";
  static const String ChangeTypeAppend = "append";
  static const double LockActionSize = 50;
  static const double LockActionMargin = 20;

  final String? targetId;
  final VoidCallback? onMenuPressed;
  final Function(String)? onSendPress;
  final Function(bool, bool, int)? onRecordTap;
  final Function(bool, bool)? onRecordLock;
  final Stream<Map<String, dynamic>>? onChangeStream;

  ChatSendBar({
    Key? key,
    required this.targetId,
    this.onMenuPressed,
    this.onSendPress,
    this.onRecordTap,
    this.onRecordLock,
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
  int _audioRecordDurationMs = 0;

  bool _audioLockedMode = false;

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
      if (_audioRecordDurationMs < AudioHelper.MessageRecordMaxDurationS * 1000 && duration.inMilliseconds >= AudioHelper.MessageRecordMaxDurationS * 1000) {
        _setAudioRecordVisible(false, true);
      }
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

    return GestureDetector(
      onTapDown: (TapDownDetails details) {
        this._onGesture(
          false,
          details.localPosition.dx,
          details.localPosition.dy,
          menuToggle: () => widget.onMenuPressed?.call(),
          sendText: () => _onSendText(),
          recordStart: () => _setAudioRecordVisible(true, false),
          recordSuccess: () => _setAudioRecordVisible(false, true),
          recordCancel: () => _setAudioRecordVisible(false, false),
        );
      },
      onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) {
        this._onGesture(
          true,
          details.localPosition.dx,
          details.localPosition.dy,
          // recordStart: () => _setAudioRecordVisible(true, false),
          // recordSuccess: () => _setAudioRecordVisible(false, true),
          // recordCancel: () => _setAudioRecordVisible(false, false),
        );
      },
      onLongPressEnd: (LongPressEndDetails details) {
        this._onGesture(
          false,
          details.localPosition.dx,
          details.localPosition.dy,
          // recordStart: () => _setAudioRecordVisible(true, false),
          recordSuccess: () => _setAudioRecordVisible(false, true),
          recordCancel: () => _setAudioRecordVisible(false, false),
        );
      },
      onTapUp: (TapUpDetails details) {
        this._onGesture(
          false,
          details.localPosition.dx,
          details.localPosition.dy,
          // recordStart: () => _setAudioRecordVisible(true, false),
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
                                type: LabelType.bodyLarge,
                                textAlign: TextAlign.center,
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
                    ? Container(
                        width: ActionWidth,
                        height: ActionHeight,
                        alignment: Alignment.center,
                        child: Label(
                          S.of(context).send,
                          type: LabelType.bodyLarge,
                          textAlign: TextAlign.center,
                          color: _theme.primaryColor,
                        ),
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
    );
  }

  _onGesture(
    bool isMove,
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
        // left
        if (!_audioRecordVisible) {
          // menu toggle
          menuToggle?.call();
        } else {
          // record info
          if (!isMove) {
            if (recordCancel != null) Toast.show("录音取消"); // TODO:GG
            recordCancel?.call();
          } else {
            this._onRecordLockAndPercentChange(false, 1);
          }
        }
      } else if (ActionWidth < offsetX && offsetX < (screenWidth! - ActionWidth)) {
        // center
        if (!_audioRecordVisible) {
          // text editing
        } else {
          // record cancel
          if (!isMove) {
            if (recordCancel != null) Toast.show("录音取消"); // TODO:GG
            recordCancel?.call();
          } else {
            double touchWidth = (screenWidth! - ActionWidth * 2);
            double percent = 1;
            if ((offsetX - ActionWidth) > (touchWidth / 2)) {
              percent = 1 - (((touchWidth / 2) - (offsetX - ActionWidth)) / (touchWidth / 2)).abs();
            }
            this._onRecordLockAndPercentChange(false, percent);
          }
        }
      } else if ((screenWidth! - ActionWidth) <= offsetX && offsetX <= screenWidth!) {
        // right
        if (_canSendText) {
          // text send
          if (!isMove) {
            sendText?.call();
          } else {}
        } else {
          if (!_audioRecordVisible) {
            // record start
            if (!isMove) {
              if (recordStart != null) Toast.show("录音开始"); // TODO:GG
              recordStart?.call();
            } else {}
          } else {
            // record success
            if (!isMove) {
              if (recordSuccess != null) Toast.show("录音成功"); // TODO:GG
              recordSuccess?.call();
            } else {
              this._onRecordLockAndPercentChange(false, 0);
            }
          }
        }
      }
    } else if (-(ChatSendBar.LockActionMargin + ChatSendBar.LockActionSize) <= offsetY && offsetY <= -ChatSendBar.LockActionMargin) {
      if (!_audioRecordVisible) {
        // nothing
      } else {
        if ((screenWidth! - ChatSendBar.LockActionMargin - ChatSendBar.LockActionSize) <= offsetX && offsetX <= (screenWidth! - ChatSendBar.LockActionMargin)) {
          // lock mode
          if (!isMove) {
            this._onRecordLockAndPercentChange(true, 0);
          } else {
            this._onRecordLockAndPercentChange(true, 0);
          }
        } else {
          // record cancel
          if (!isMove) {
            if (recordCancel != null) Toast.show("录音取消"); // TODO:GG
            recordCancel?.call();
          } else {
            this._onRecordLockAndPercentChange(false, 1);
          }
        }
      }
    } else {
      if (!_audioRecordVisible) {
        // nothing
      } else {
        if (!isMove) {
          // record cancel
          if (recordCancel != null) Toast.show("录音取消"); // TODO:GG
          recordCancel?.call();
        } else {
          this._onRecordLockAndPercentChange(false, 1);
        }
      }
    }
  }

  _onRecordLockAndPercentChange(bool lockMode, double percent) {
    bool lockModeChange = _audioLockedMode != lockMode;
    if (_audioLockedMode != lockMode || _audioDragPercent != percent) {
      setState(() {
        _audioLockedMode = lockMode;
        _audioDragPercent = percent > 1 ? 1 : percent;
      });
    }
    if (lockModeChange) widget.onRecordLock?.call(true, lockMode);
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
    var durationMs = visible ? 0 : _audioRecordDurationMs;
    bool lockMode = visible ? _audioLockedMode : false;
    double percent = visible ? _audioDragPercent : 0;
    this.setState(() {
      _audioRecordVisible = visible;
      _audioRecordDurationMs = durationMs;
      _audioLockedMode = lockMode;
      _audioDragPercent = percent > 1 ? 1 : percent;
    });
    widget.onRecordLock?.call(visible, lockMode);
    widget.onRecordTap?.call(visible, complete, _audioRecordDurationMs); // await
  }
}

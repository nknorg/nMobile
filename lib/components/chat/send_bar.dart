import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/text/label.dart';
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
  final bool? enable;
  final VoidCallback? onMenuPressed;
  final Function(String)? onSendPress;
  final Function(bool)? onInputFocus;
  final Function(bool, bool, int)? onRecordTap;
  final Function(bool, bool)? onRecordLock;
  final Stream<Map<String, dynamic>>? onChangeStream;

  ChatSendBar({
    Key? key,
    required this.targetId,
    this.enable,
    this.onMenuPressed,
    this.onSendPress,
    this.onInputFocus,
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
  TextEditingController _inputController = TextEditingController();
  FocusNode _inputFocusNode = FocusNode();

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
    // input
    _onChangeSubscription = widget.onChangeStream?.listen((event) {
      String? type = event["type"];
      if (type == null || type.isEmpty) return;
      if (type == ChatSendBar.ChangeTypeReplace) {
        _inputController.text = event["content"] ?? "";
      } else if (type == ChatSendBar.ChangeTypeAppend) {
        _inputController.text += event["content"] ?? "";
      }
      setState(() {
        _canSendText = _inputController.text.isNotEmpty;
      });
    });
    _inputFocusNode.addListener(() {
      widget.onInputFocus?.call(_inputFocusNode.hasFocus);
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
      _inputController.text = _draft!;
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
            recordCancel?.call();
          } else {
            this._onRecordLockAndPercentChange(false, 1);
          }
        }
      } else if (ActionWidth < offsetX && offsetX < (Global.screenWidth() - ActionWidth)) {
        // center
        if (!_audioRecordVisible) {
          // text editing
        } else {
          // record cancel
          if (!isMove) {
            recordCancel?.call();
          } else {
            double touchWidth = (Global.screenWidth() - ActionWidth * 2);
            double percent = 1;
            if ((offsetX - ActionWidth) > (touchWidth / 2)) {
              percent = 1 - (((touchWidth / 2) - (offsetX - ActionWidth)) / (touchWidth / 2)).abs();
            }
            this._onRecordLockAndPercentChange(false, percent);
          }
        }
      } else if ((Global.screenWidth() - ActionWidth) <= offsetX && offsetX <= Global.screenWidth()) {
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
              recordStart?.call();
            } else {}
          } else {
            // record success
            if (!isMove) {
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
        if ((Global.screenWidth() - ChatSendBar.LockActionMargin - ChatSendBar.LockActionSize) <= offsetX && offsetX <= (Global.screenWidth() - ChatSendBar.LockActionMargin)) {
          // lock mode
          if (!isMove) {
            this._onRecordLockAndPercentChange(true, 0);
          } else {
            this._onRecordLockAndPercentChange(true, 0);
          }
        } else {
          // record cancel
          if (!isMove) {
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
          recordCancel?.call();
        } else {
          this._onRecordLockAndPercentChange(false, 1);
        }
      }
    }
  }

  _onRecordLockAndPercentChange(bool lockMode, double percent) {
    bool canLock = false;
    bool lockModeChange = _audioLockedMode != lockMode;
    if (lockModeChange) canLock = widget.onRecordLock?.call(true, lockMode);
    if (_audioLockedMode != lockMode || _audioDragPercent != percent) {
      setState(() {
        _audioLockedMode = canLock && lockMode;
        _audioDragPercent = percent > 1 ? 1 : percent;
      });
    }
  }

  _onSendText() {
    String content = _inputController.text;
    if (content.isEmpty) return;
    _inputController.clear();
    setState(() {
      _canSendText = false;
    });
    memoryCache.removeDraft(widget.targetId);
    widget.onSendPress?.call(content); // await
  }

  _setAudioRecordVisible(bool visible, bool complete) async {
    if (visible == _audioRecordVisible) return;
    var durationMs = visible ? 0 : _audioRecordDurationMs;
    bool lockMode = visible ? _audioLockedMode : false;
    double percent = visible ? _audioDragPercent : 0;
    bool canLock = widget.onRecordLock?.call(visible, lockMode);
    this.setState(() {
      _audioRecordVisible = visible;
      _audioRecordDurationMs = durationMs;
      _audioLockedMode = canLock && lockMode;
      _audioDragPercent = percent > 1 ? 1 : percent;
    });
    var result = await widget.onRecordTap?.call(visible, complete, _audioRecordDurationMs);
    if (visible && result == false) {
      _setAudioRecordVisible(false, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    SkinTheme _theme = application.theme;

    Color? recordWidgetColor = _audioTextColorTween.transform(_audioDragPercent);
    Color? volumeColor = (_audioRecordDurationMs % 1000) <= 500 ? recordWidgetColor : Colors.transparent;

    Duration recordDuration = Duration(milliseconds: _audioRecordDurationMs);
    String recordMin = "${recordDuration.inMinutes < 10 ? 0 : ""}${recordDuration.inMinutes}";
    String recordSec = "${recordDuration.inSeconds < 10 ? 0 : ""}${recordDuration.inSeconds}";
    String recordDurationText = "$recordMin:$recordSec";

    if (widget.enable == false) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: Button(
          child: Label(
            S.of(context).tip_ask_group_owner_permission,
            type: LabelType.h4,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            color: application.theme.backgroundColor5,
          ),
          backgroundColor: application.theme.backgroundColor3,
          width: double.infinity,
        ),
      );
    }

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
        color: application.theme.backgroundColor1,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Stack(
                children: [
                  Row(
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
                        child: Container(
                          decoration: BoxDecoration(
                            color: _theme.backgroundColor2,
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Expanded(
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
                                  controller: _inputController,
                                  focusNode: _inputFocusNode,
                                  textInputAction: TextInputAction.newline,
                                  onChanged: (val) {
                                    String draft = _inputController.text;
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
                  ),
                  _audioRecordVisible
                      ? Container(
                          color: application.theme.backgroundColor1,
                          child: Container(
                            color: _audioBgColorTween.transform(_audioDragPercent),
                            child: Row(
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
                                SizedBox(width: 16),
                              ],
                            ),
                          ),
                        )
                      : SizedBox.shrink()
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
                        color: application.theme.backgroundColor1,
                        child: Label(
                          S.of(context).send,
                          type: LabelType.bodyLarge,
                          textAlign: TextAlign.center,
                          color: _theme.primaryColor,
                        ),
                      )
                    : Container(
                        color: application.theme.backgroundColor1,
                        child: Container(
                          color: _audioBgColorTween.transform(_audioDragPercent),
                          child: SizedBox(
                            width: ActionWidth,
                            height: ActionHeight,
                            child: UnconstrainedBox(
                              child: Asset.iconSvg(
                                'microphone',
                                width: 24,
                                color: !_canSendText ? _theme.primaryColor : _theme.fontColor2,
                              ),
                            ),
                          ),
                        ),
                      )),
            // _voiceAndSendWidget(),
          ],
        ),
      ),
    );
  }
}

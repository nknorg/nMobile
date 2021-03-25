

import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/components/button_icon.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/screens/chat/record_audio.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:nmobile/utils/nlog_util.dart';
import 'package:oktoast/oktoast.dart';
import 'package:vibration/vibration.dart';


typedef sendAudioFunction = Future Function();

class ChatMenu extends StatefulWidget {
  bool showAudioInput = false;

  bool showAudioLock = false;
  double audioLockHeight = 90;

  final Function sendAudioFunction;

  ChatMenu(
      {Key key,
        this.sendAudioFunction})
      : super(key: key);

  @override
  _ChatMenuState createState() => _ChatMenuState();
}

class _ChatMenuState extends State<ChatMenu> {
  RecordAudio _recordAudio;
  DateTime cTime;

  bool _audioLongPressEndStatus = false;


  // final Function startRecord;
  // final Function stopRecord;
  // final Function cancelRecord;
  //
  // final Function updateLongPressFunction;
  //
  // final double height;
  // final EdgeInsets margin;
  // final Decoration decoration;
  //
  // /// startRecord callback function  stopRecord
  // RecordAudio(
  //     {Key key,
  //       this.startRecord,
  //       this.stopRecord,
  //       this.cancelRecord,
  //       this.updateLongPressFunction,
  //       this.height,
  //       this.decoration,
  //       this.margin})
  //     : super(key: key);

  @override
  Widget build(BuildContext context) {
    double wWidth = MediaQuery.of(context).size.width;
    return Container(
      height: 90,
      margin: EdgeInsets.only(bottom: 0),
      child: GestureDetector(
        child: _menuWidget(),
        onTapUp: (details) {
          int afterSeconds =
              DateTime.now().difference(cTime).inSeconds;
          setState(() {
            widget.showAudioLock = false;
            if (afterSeconds > 1) {
              /// send AudioMessage Here
              NLog.w('Audio record less than 1s' +
                  afterSeconds.toString());
            } else {
              /// add viberation Here
              widget.showAudioInput = false;
            }
          });
        },
        onLongPressStart: (details) {
          cTime = DateTime.now();
          widget.showAudioLock = false;
          Vibration.vibrate();
          _setAudioInputOn(true);
        },
        onLongPressEnd: (details) {
          int afterSeconds =
              DateTime.now().difference(cTime).inSeconds;
          setState(() {
            if (details.globalPosition.dx < (wWidth - 80)){
              if (_recordAudio != null) {
                _recordAudio.cancelCurrentRecord();
                _recordAudio.cOpacity = 1;
              }
            }
            else{
              if (_recordAudio.showLongPressState == false) {

              } else {
                _recordAudio.stopAndSendAudioMessage();
              }
            }
            if (afterSeconds > 0.2 &&
                _recordAudio.cOpacity > 0) {
            } else {
              widget.showAudioInput = false;
            }
            if (widget.showAudioLock) {
              widget.showAudioLock = false;
            }
          });
        },
        onLongPressMoveUpdate: (details) {
          int afterSeconds =
              DateTime.now().difference(cTime).inSeconds;
          if (afterSeconds > 0.2) {
            setState(() {
              widget.showAudioLock = true;
            });
          }
          if (details.globalPosition.dx >
              (wWidth) / 3 * 2 &&
              details.globalPosition.dx < wWidth - 80) {
            double cX = details.globalPosition.dx;
            double tW = wWidth - 80;
            double mL = (wWidth) / 3 * 2;
            double tL = tW - mL;
            double opacity = (cX - mL) / tL;
            if (opacity < 0) {
              opacity = 0;
            }
            if (opacity > 1) {
              opacity = 1;
            }

            setState(() {
              _recordAudio.cOpacity = opacity;
            });
          } else if (details.globalPosition.dx > wWidth - 80) {
            setState(() {
              _recordAudio.cOpacity = 1;
            });
          }
          double gapHeight = 90;
          double tL = 50;
          double mL = 60;
          if (details.globalPosition.dy >
              MediaQuery.of(context).size.height -
                  (gapHeight + tL) &&
              details.globalPosition.dy <
                  MediaQuery.of(context).size.height -
                      gapHeight) {
            setState(() {
              double currentL = (tL -
                  (MediaQuery.of(context).size.height -
                      details.globalPosition.dy -
                      gapHeight));
              widget.audioLockHeight = mL + currentL - 10;
              if (widget.audioLockHeight < mL) {
                widget.audioLockHeight = mL;
              }
            });
          }
          if (details.globalPosition.dy <
              MediaQuery.of(context).size.height -
                  (gapHeight + tL)) {
            setState(() {
              widget.audioLockHeight = mL;
              _recordAudio.showLongPressState = false;
              _audioLongPressEndStatus = true;
            });
          }
          if (details.globalPosition.dy >
              MediaQuery.of(context).size.height -
                  (gapHeight)) {
            widget.audioLockHeight = 90;
          }
        },
        onHorizontalDragEnd: (details) {
          _cancelAudioRecord();
        },
        onHorizontalDragCancel: () {
          _cancelAudioRecord();
        },
        onVerticalDragCancel: () {
          _cancelAudioRecord();
        },
        onVerticalDragEnd: (details) {
          _cancelAudioRecord();
        },
      ),
    );
  }

  _voiceAction() {
    _setAudioInputOn(true);
    Vibration.vibrate();
    Timer(Duration(milliseconds: 350), () async {
      _setAudioInputOn(false);
    });
  }

  _setAudioInputOn(bool audioInputOn) {
    setState(() {
      if (audioInputOn) {
        widget.showAudioInput = true;
      } else {
        widget.showAudioInput = false;
      }
    });
  }

  _cancelRecord() {
    _setAudioInputOn(false);
    Vibration.vibrate();
  }

  startRecord() {
    NLog.w('startRecord called');
  }

  stopRecord(String path, double audioTimeLength) async {
    NLog.w('stopRecord called');
    _setAudioInputOn(false);

    File audioFile = File(path);
    if (!audioFile.existsSync()) {
      audioFile.createSync();
      audioFile = File(path);
    }
    int fileLength = await audioFile.length();

    if (fileLength != null && audioTimeLength != null) {
      NLog.w('Record finished with fileLength__' +
          fileLength.toString() +
          'audioTimeLength is__' +
          audioTimeLength.toString());
    }
    if (fileLength == 0) {
      showToast('Record file wrong.Please record again.');
      return;
    }
    if (audioTimeLength > 1.0) {
      widget.sendAudioFunction(audioFile, audioTimeLength);
    }
  }

  _cancelAudioRecord() {
    if (_audioLongPressEndStatus == false) {
      if (_recordAudio != null) {
        _recordAudio.cancelCurrentRecord();
      }
    }
    setState(() {
      widget.showAudioLock = false;
    });
  }

  Widget _menuWidget() {
    return Container();
    // double audioHeight = 65;
    // if (widget.showAudioInput == true) {
    //   if (_recordAudio == null) {
    //     _recordAudio = RecordAudio(
    //       height: audioHeight,
    //       margin: EdgeInsets.only(top: 15, bottom: 15, right: 0),
    //       startRecord: startRecord,
    //       stopRecord: stopRecord,
    //       cancelRecord: _cancelRecord,
    //     );
    //   }
    //   return Container(
    //     height: audioHeight,
    //     margin: EdgeInsets.only(top: 15, right: 0),
    //     child: _recordAudio,
    //   );
    // }
    // return Container(
    //   constraints: BoxConstraints(minHeight: 70, maxHeight: 160),
    //   child: Flex(
    //     direction: Axis.horizontal,
    //     crossAxisAlignment: CrossAxisAlignment.end,
    //     children: <Widget>[
    //       Expanded(
    //         flex: 0,
    //         child: Container(
    //           margin:
    //           const EdgeInsets.only(left: 0, right: 0, top: 15, bottom: 15),
    //           padding: const EdgeInsets.only(left: 8, right: 8),
    //           child: ButtonIcon(
    //             width: 50,
    //             height: 50,
    //             icon: loadAssetIconsImage(
    //               'grid',
    //               width: 24,
    //               color: DefaultTheme.primaryColor,
    //             ),
    //             onPressed: () {
    //               _toggleBottomMenu();
    //             },
    //           ),
    //         ),
    //       ),
    //       _sendWidget(),
    //       _voiceAndSendWidget(),
    //     ],
    //   ),
    // );
  }

  // Widget _sendWidget() {
  //   return Expanded(
  //     flex: 1,
  //     child: Container(
  //       margin: const EdgeInsets.only(left: 0, right: 0, top: 15, bottom: 15),
  //       decoration: BoxDecoration(
  //         color: DefaultTheme.backgroundColor1,
  //         borderRadius: BorderRadius.all(Radius.circular(20)),
  //       ),
  //       child: Flex(
  //         direction: Axis.horizontal,
  //         crossAxisAlignment: CrossAxisAlignment.end,
  //         children: <Widget>[
  //           Expanded(
  //             flex: 1,
  //             child: TextField(
  //               maxLines: 5,
  //               minLines: 1,
  //               controller: _sendController,
  //               focusNode: _sendFocusNode,
  //               textInputAction: TextInputAction.newline,
  //               onChanged: (val) {
  //                 if (mounted) {
  //                   setState(() {
  //                     _canSend = val.isNotEmpty;
  //                   });
  //                 }
  //               },
  //               style: TextStyle(fontSize: 14, height: 1.4),
  //               decoration: InputDecoration(
  //                 hintText: NL10ns.of(context).type_a_message,
  //                 contentPadding:
  //                 EdgeInsets.symmetric(vertical: 8, horizontal: 12),
  //                 border: UnderlineInputBorder(
  //                   borderRadius: BorderRadius.all(Radius.circular(20)),
  //                   borderSide:
  //                   const BorderSide(width: 0, style: BorderStyle.none),
  //                 ),
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
}
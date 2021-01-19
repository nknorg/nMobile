import 'dart:async';
import 'dart:io';

import 'package:common_utils/common_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';


typedef startRecord = Future Function();
typedef stopRecord = Future Function();

class RecordAudio extends StatefulWidget {
  final Function startRecord;
  final Function stopRecord;
  final Function cancelRecord;

  final Function updateLongPressFunction;

  final double height;
  final EdgeInsets margin;
  final Decoration decoration;

  /// startRecord 开始录制回调  stopRecord回调
  RecordAudio(
      {Key key,
        this.startRecord,
        this.stopRecord,
        this.cancelRecord,
        this.updateLongPressFunction,
        this.height,
        this.decoration,
        this.margin})
      : super(key: key);

  @override
  _RecordAudioState createState() => _RecordAudioState();

  double moveLeftValue = 0.0;
  double moveUpValue = 0.0;

  Function cancelCurrentRecord;

  Function stopAndSendAudioMessage;

  bool showLongPressState = false;

  double cOpacity = 1.0;
}

class _RecordAudioState extends State<RecordAudio> {

  /// countDown audio duration
  int _maxLength = 60;

  double starty = 0.0;
  // double offset = 0.0;
  bool isUp = false;
  // String textShow = "按住说话";
  // String toastShow = "手指上滑,取消发送";
  // String voiceIco = "images/voice_volume_1.png";

  String recordLength = '0:00';
  String cancelText = '取消';
  Color recordingColor = Colors.red;


  /// LongPress Var
  String moveLeftToCancelRecord = '<  滑动以取消  <';

  ///默认隐藏状态
  bool voiceState = true;
  Timer _timer;
  int _count = 0;
  OverlayEntry overlayEntry;

  FlutterSoundPlayer _mPlayer = FlutterSoundPlayer();
  FlutterSoundRecorder _mRecorder = FlutterSoundRecorder();

  StreamSubscription _recorderSubscription;
  StreamSubscription _playerSubscription;

  bool _mPlayerIsInited = false;
  bool _mRecorderIsInited = false;
  // bool _mPlaybackReady = false;
  String _mPath;

  double duration = 0.0;
  int durationSeconds = 0;
  // Map dbMap = Map();

  double containerHeight = 65;

  @override
  void initState() {
    _mPlayer.openAudioSession().then((value) {
      setState(() {
        _mPlayerIsInited = true;
      });
    });
    super.initState();
    openTheRecorder().then((value) {
      setState(() {
        _mRecorderIsInited = true;
      });
    });

    widget.showLongPressState = true;
    _init();
  }

  ///初始化语音录制的方法
  void _init() async {
    await _mRecorder.openAudioSession(
        focus: AudioFocus.requestFocusTransient,
        category: SessionCategory.playAndRecord,
        mode: SessionMode.modeDefault,
        device: AudioDevice.speaker);
    await _mPlayer.closeAudioSession();

    await _mPlayer.openAudioSession(
        focus: AudioFocus.requestFocusTransient,
        category: SessionCategory.playAndRecord,
        mode: SessionMode.modeDefault,
        device: AudioDevice.speaker);

    await _mPlayer.setSubscriptionDuration(Duration(milliseconds: 60));
    await _mRecorder.setSubscriptionDuration(Duration(milliseconds: 60));

    widget.cancelCurrentRecord = ()=>cancelCurrentRecordFunction();
    widget.stopAndSendAudioMessage = ()=>stopAndSendRecordFunction();

    startR();
  }

  _startRecordSubscription(){
    /// 监听录音
    _recorderSubscription = _mRecorder.onProgress.listen((info) {
      if (info != null && info.duration != null) {
        DateTime date = new DateTime.fromMillisecondsSinceEpoch(
            info.duration.inMilliseconds,
            isUtc: true);
        if (date.second >= _maxLength) {
          _stopRecordButNotSend();
        }

        setState(() {
          var _dbLevel = info.decibels;
          durationSeconds = date.second;

          duration = date.second+date.millisecond/1000;
          duration = (NumUtil.getNumByValueDouble(duration, 2));

          if (date.millisecond > 500){
            recordingColor = Colors.red;
          }
          else{
            recordingColor = Colors.transparent;
          }

          recordLength = '0:'+durationSeconds.toString();
          if(durationSeconds < 10) {
            recordLength = '0:0'+durationSeconds.toString();
          }
          String mapKey = duration.toString();
          // dbMap[mapKey] = (NumUtil.getNumByValueDouble(_dbLevel, 2)).toStringAsFixed(2);
        });
      }
    });
  }

  ///开始语音录制的方法
  void startR() async {
    startRecordFunc();
    _startRecordSubscription();

    _timer = Timer.periodic(Duration(milliseconds: 1000), (t) {
      _count++;
      if (_count == _maxLength) {
        _stopRecordButNotSend();
        /// 展示已完成录音
      }
    });
  }

  _stopRecordButNotSend(){
    _mPlayer.stopPlayer();
    _mRecorder.pauseRecorder();
    _cancelRecorderSubscriptions();
    _timer.cancel();
    _timer = null;
  }

  /// For Message to cancel
  cancelCurrentRecordFunction() {
    widget.cancelRecord();
    _resetAudio();
  }

  /// For Message to stop
  stopAndSendRecordFunction() async{
    await _mRecorder.stopRecorder();
    await _mPlayer.stopPlayer();
    _cancelRecorderSubscriptions();
    _timer.cancel();
    _timer = null;

    widget.stopRecord(_mPath, duration);
  }

  _cancelRecord() {
    print('moveLeftToCancelRecord__'+moveLeftToCancelRecord.toString());
    if (moveLeftToCancelRecord == '取消'){
      widget.cancelRecord();
      _resetAudio();
    }
  }

  @override
  Widget build(BuildContext context) {
    double cellWidth = MediaQuery.of(context).size.width/3;


    return Opacity(
      opacity: widget.cOpacity,
      child: Container(
        height: containerHeight,
        margin: EdgeInsets.only(top: 15, bottom: 15),
        child: Row(
          children: [
            Container(
              height: containerHeight,
              width: 40,
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Icon(
                  FontAwesomeIcons.microphone,
                  size: 24,
                  color: recordingColor
              ),
            ),
            Container(
              width: cellWidth-40,
              child: Label(
                  recordLength,
                  type: LabelType.bodyRegular,
                  fontWeight: FontWeight.normal,
                  color: Colors.red
              ),
            ),
            Container(
              width: cellWidth,
              child: _longPressOffDescWidget(),
            ),
            Spacer(),
            _sendWidget(),
          ],
        ),
      ),
    );
  }

  Widget _sendWidget() {
    if (widget.showLongPressState){
      return Container(
        child: Stack(
          overflow: Overflow.visible,
          children: [
            Container(
              width: 50,
              height: containerHeight,
              color: Colors.red,
            ),
            Positioned(
              bottom: -30,
              right: -20,
              child: Container(
                  height: 90,
                  width: 90,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(45),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: loadAssetIconsImage('microphone', color: Colors.white, width: 60,),
                  )
              ),
            ),
          ],
        ),
      );
    }
    String sendText = '发送';
    return GestureDetector(
      child: Container(
        margin: EdgeInsets.only(right: 16,left: 5),
        child: Label(
          sendText,
          type: LabelType.bodyLarge,
          fontWeight: FontWeight.normal,
          color: Colors.red,
          textAlign: TextAlign.center,
        ),
      ),
      onTap:()=> stopAndSendRecordFunction(),
    );
  }

  Widget _longPressOffDescWidget() {
    LabelType lType = LabelType.bodyRegular;
    if (widget.showLongPressState == false){
      moveLeftToCancelRecord = cancelText;
      lType = LabelType.bodyLarge;
    }
    return GestureDetector(
      child: Container(
        child: Label(
          moveLeftToCancelRecord,
          type: lType,
          fontWeight: FontWeight.normal,
          color: Colors.red,
          textAlign: TextAlign.center,
        ),
      ),
      onTap:()=>_cancelRecord(),
    );
    // if (widget.showLongPressState == false){
    //
    // }
    // return GestureDetector(
    //   child: Container(
    //     margin: EdgeInsets.only(top: 10, bottom: 10),
    //     child: Label(
    //       moveLeftToCancelRecord,
    //       type: LabelType.bodyRegular,
    //       fontWeight: FontWeight.normal,
    //       color: Colors.red,
    //       textAlign: TextAlign.center,
    //     ),
    //   ),
    //   onTap: ()=>_cancelRecord(),
    // );
  }

  // Widget _sendWidget(BuildContext context) {
  //   double cellWidth = MediaQuery.of(context).size.width/3;
  //   // if (showLongPressState) {
  //   //   return Container(
  //   //     margin: const EdgeInsets.only(left: 0, right: 0, top:15, bottom: 15),
  //   //     child: ButtonIcon(
  //   //       width: 50,
  //   //       height: 50,
  //   //       icon:
  //   //       loadAssetIconsImage('microphone', color: DefaultTheme.primaryColor, width: 24,),
  //   //       // onPressed: () {
  //   //       //   // _voiceAction();
  //   //       // },
  //   //     )
  //   //   );
  //   //     // GestureDetector(
  //   //     // onLongPressStart: (details) {
  //   //     //   print('on _voiceWidget LongPressStart');
  //   //     //   setState(() {
  //   //     //     showLongPressState = true;
  //   //     //     // _showAudioInput = true;
  //   //     //   });
  //   //     // },
  //   //     // onLongPressEnd: (details) {
  //   //     //   print('on _voiceWidget LongPressStart End');
  //   //     //   setState(() {
  //   //     //     showLongPressState = false;
  //   //     //     // _showAudioInput = false;
  //   //     //   });
  //   //     // },
  //   //     // onLongPressMoveUpdate: (details) {
  //   //     //   print('onLongPressStart Move__'+details.globalPosition.dy.toString()+'____'+details.globalPosition.dx.toString());
  //   //     //   // moveVoiceView();
  //   //     //   setState(() {
  //   //     //     moveLeftValue = details.globalPosition.dx;
  //   //     //   });
  //   //     // },
  //   //     // child:
  //   //     // ),
  //   //   );
  //   // }
  //   return GestureDetector(
  //     child: Container(
  //       margin: EdgeInsets.only(top: 10, bottom: 10, right: 16),
  //       height: 30,
  //       width: cellWidth-16,
  //       child: Label(
  //         sendText,
  //         type: LabelType.bodyLarge,
  //         fontWeight: FontWeight.normal,
  //         color: DefaultTheme.primaryColor,
  //         textAlign: TextAlign.right,
  //       ),
  //     ),
  //     onTap:()=>_sendRecord(),
  //   );
  // }
  // Widget _longPressVoice(BuildContext context) {
  //   double cellWidth = MediaQuery.of(context).size.width/3;
  //   return Container(
  //     height: 50,
  //     width: cellWidth,
  //     margin: EdgeInsets.only(bottom: 10),
  //
  //   );
  // }

  Future<void> openTheRecorder() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }

    await _resetMPath();
    await _mRecorder.openAudioSession();
    _mRecorderIsInited = true;
  }

  _resetMPath() async{
    var tempDir = await getApplicationDocumentsDirectory();
    DateTime nowDate = DateTime.now();
    String name = nowDate.toString().replaceAll(new RegExp(r"\s+\b|\b\s"), "");
    name = name+'.aac';

    _mPath = join(tempDir.path, NKNClientCaller.pubKey,name);
    var outputFile = File(_mPath);
    if (outputFile.existsSync()) {
      await outputFile.delete();
    }
  }

  Future<void> startRecordFunc() async {
    await _resetMPath();
    await _mRecorder.startRecorder(
      toFile: _mPath,
      codec: Codec.aacADTS,
    );
    setState(() {});
  }

  Future<void> stopRecordFunc() async {
    await _mRecorder.stopRecorder();

    print('Up MPath is__'+_mPath);
    widget.stopRecord(_mPath, duration);
    // _mPlaybackReady = true;

    print('Up MPath is__'+_mPath);
    _timer.cancel();
    _timer = null;
  }

  /// 取消录音监听
  void _cancelRecorderSubscriptions() {
    if (_recorderSubscription != null) {
      _recorderSubscription.cancel();
      _recorderSubscription = null;
    }
  }

  /// 取消播放监听
  void _cancelPlayerSubscriptions() {
    if (_playerSubscription != null) {
      _playerSubscription.cancel();
      _playerSubscription = null;
    }
  }

  _resetAudio() {
    _cancelRecorderSubscriptions();
    _cancelPlayerSubscriptions();

    if (_mRecorder.isRecording){
      _mRecorder.stopRecorder();
    }
    _mRecorder.closeAudioSession();
    _mRecorder = null;

    _timer.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _resetAudio();
    super.dispose();
  }

}

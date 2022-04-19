import 'dart:async';
import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart' as Sound;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/tip/toast.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:audioplayers/audioplayers.dart' as Player;

class AudioHelper with Tag {
  static const double MessageRecordMaxDurationS = 60;
  static const double MessageRecordMinDurationS = 0.5;

  // player
  Sound.FlutterSoundPlayer player = Sound.FlutterSoundPlayer();
  String? playerId;
  int? playerDurationMs;
  StreamSubscription? _onPlayProgressSubscription;
  bool isPlayReleasing = false;

  // ignore: close_sinks
  StreamController<Map<String, dynamic>> _onPlayProgressController = StreamController<Map<String, dynamic>>.broadcast();
  StreamSink<Map<String, dynamic>> get _onPlayProgressSink => _onPlayProgressController.sink;
  Stream<Map<String, dynamic>> get onPlayProgressStream => _onPlayProgressController.stream; // .distinct((prev, next) => (prev['player_id'] == next['player_id']) && (next['percent'] < prev['percent']));

  // record
  Sound.FlutterSoundRecorder record = Sound.FlutterSoundRecorder();
  String? recordId;
  String? recordPath;
  double? recordMaxDurationS;
  StreamSubscription? _onRecordProgressSubscription;
  bool isRecordReleasing = false;

  // ignore: close_sinks
  StreamController<Map<String, dynamic>> _onRecordProgressController = StreamController<Map<String, dynamic>>.broadcast();
  StreamSink<Map<String, dynamic>> get _onRecordProgressSink => _onRecordProgressController.sink;
  Stream<Map<String, dynamic>> get onRecordProgressStream => _onRecordProgressController.stream; // .distinct((prev, next) => (prev['player_id'] == next['player_id']) && (next['percent'] < prev['percent']));

  AudioHelper();

  Future<String?> _getRecordPath(String? targetId) async {
    if (clientCommon.publicKey == null || clientCommon.publicKey!.isEmpty) return null;
    String recordPath = await Path.getRandomFile(hexEncode(clientCommon.publicKey!), SubDirType.chat, target: targetId, fileExt: 'aac');
    var outputFile = File(recordPath);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }
    outputFile = await outputFile.create(recursive: true);
    return outputFile.path;
  }

  ///***********************************************************************************************************************
  ///******************************************************* Player ********************************************************
  ///***********************************************************************************************************************

  Future<bool> playStart(String playerId, String localPath, {int? durationMs, Function(PlaybackDisposition)? onProgress}) async {
    logger.i("$TAG - playStart - playerId:$playerId - localPath:$localPath - durationMs:$durationMs");
    if (isPlayReleasing) return false;
    // permission
    var status = await Permission.storage.request();
    if (status != PermissionStatus.granted) {
      await playStop();
      throw RecordingPermissionException('Storage permission not granted');
    }
    if (status != PermissionStatus.granted) {
      await playStop();
      return false;
    }
    // playing
    if (!player.isStopped) {
      bool isSame = playerId == this.playerId;
      await playStop();
      if (isSame) return true;
    }
    // path
    File localFile = File(localPath);
    if (localPath.isEmpty || !localFile.existsSync()) {
      Toast.show(Global.locale((s) => s.file_not_exist));
      return false;
    }
    if (Platform.isAndroid) localPath = 'file:///' + localPath;
    // init
    Sound.FlutterSoundPlayer? _player;
    try {
      _player = await player.openAudioSession(
        focus: AudioFocus.requestFocusAndStopOthers,
        category: Sound.SessionCategory.playback,
        mode: SessionMode.modeVoiceChat,
        device: AudioDevice.speaker,
      );
    } catch (e) {
      handleError(e);
    }
    if (_player == null) {
      await playStop();
      return false;
    }
    this.player = _player;
    this.playerId = playerId;
    this.playerDurationMs = durationMs;
    // progress
    if (_onPlayProgressSubscription != null) {
      _onPlayProgressSubscription?.cancel();
    }
    _onPlayProgressSubscription = player.onProgress?.listen((PlaybackDisposition event) async {
      // logger.d("$TAG - playStart - onProgress - recordId:${this.playerId} - duration:${event.duration} - position:${event.position}");
      onProgress?.call(event);
      int duration = event.duration.inMinutes * 60 * 1000 + event.duration.inSeconds * 1000 + event.duration.inMilliseconds;
      int position = event.position.inMinutes * 60 * 1000 + event.position.inSeconds * 1000 + event.position.inMilliseconds;
      _onPlayProgressSink.add({
        "id": this.playerId,
        "duration": duration,
        "position": position,
        "percent": position / duration,
      });
    });
    // start
    try {
      await player.setSubscriptionDuration(Duration(milliseconds: 50));
      await player.startPlayer(
          fromDataBuffer: localFile.readAsBytesSync(),
          codec: Codec.defaultCodec,
          whenFinished: () {
            logger.i("$TAG - playStart - whenFinished - playerId:$playerId");
            _onPlayProgressSink.add({
              "id": this.playerId,
              "duration": this.playerDurationMs,
              "position": 0,
              "percent": 0,
            });
            playStop();
          });
    } catch (e) {
      handleError(e);
    }
    _onPlayProgressSink.add({
      "id": this.playerId,
      "duration": this.playerDurationMs,
      "position": 0.01,
      "percent": 0.01,
    });
    return true;
  }

  Future<bool> playStop() async {
    logger.i("$TAG - playStop - playerId:$playerId");
    isPlayReleasing = true;
    _onPlayProgressSink.add({
      "id": this.playerId,
      "duration": this.playerDurationMs,
      "position": 0,
      "percent": 0,
    });
    _onPlayProgressSubscription?.cancel();
    _onPlayProgressSubscription = null;
    try {
      await player.stopPlayer();
      await player.closeAudioSession();
    } catch (e) {
      handleError(e);
      isPlayReleasing = false;
    }
    this.playerId = null;
    // this.playerDuration = null;
    isPlayReleasing = false;
    return true;
  }

  Future<bool> playerRelease() async {
    logger.i("$TAG - playerRelease");
    await playStop();
    return true;
  }

  ///***********************************************************************************************************************
  ///******************************************************* Record ********************************************************
  ///***********************************************************************************************************************

  Future<String?> recordStart(String recordId, {String? savePath, double? maxDurationS, Function(RecordingDisposition)? onProgress}) async {
    logger.i("$TAG - recordStart - recordId:$recordId - savePath:$savePath - maxDurationS:$maxDurationS");
    if (isRecordReleasing) return null;
    // permission
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      await recordStop();
      throw RecordingPermissionException('Microphone permission not granted');
    }
    if (status != PermissionStatus.granted) {
      await recordStop();
      return null;
    }
    // recording
    if (!record.isStopped) {
      await recordStop();
    }
    // path
    this.recordPath = savePath ?? await _getRecordPath(recordId);
    if (recordPath == null || recordPath!.isEmpty) {
      await recordStop();
      return null;
    }
    // init
    FlutterSoundRecorder? _record;
    try {
      _record = await record.openAudioSession(
        focus: AudioFocus.requestFocusAndStopOthers,
        category: Sound.SessionCategory.record,
        mode: SessionMode.modeDefault,
        device: AudioDevice.speaker,
      );
    } catch (e) {
      handleError(e);
    }
    if (_record == null) {
      await recordStop();
      return null;
    }
    this.record = _record;
    this.recordId = recordId;
    this.recordMaxDurationS = maxDurationS;
    // progress
    if (_onRecordProgressSubscription != null) {
      _onRecordProgressSubscription?.cancel();
    }
    _onRecordProgressSubscription = record.onProgress?.listen((RecordingDisposition event) async {
      // logger.d("$TAG - recordStart - onProgress - recordId:${this.recordId} - duration:${event.duration} - volume:${event.decibels}");
      onProgress?.call(event);
      _onRecordProgressSink.add({
        "id": this.recordId,
        "duration": event.duration,
        "volume": (event.decibels ?? 0) / 120,
      });
      // maxDuration
      if (this.recordMaxDurationS != null && this.recordMaxDurationS! > 0) {
        if (event.duration.inMilliseconds >= this.recordMaxDurationS! * 1000) {
          await recordStop();
        }
      }
    });
    // start
    try {
      await record.setSubscriptionDuration(Duration(milliseconds: 50));
      await record.startRecorder(toFile: recordPath, codec: Sound.Codec.aacADTS);
    } catch (e) {
      handleError(e);
    }
    return recordPath;
  }

  Future<String?> recordStop() async {
    logger.i("$TAG - recordStop - recordId:$recordId");
    isRecordReleasing = true;
    _onRecordProgressSubscription?.cancel();
    _onRecordProgressSubscription = null;
    try {
      await record.stopRecorder();
      await record.closeAudioSession();
    } catch (e) {
      handleError(e);
      isRecordReleasing = false;
    }
    this.recordId = null;
    // this.recordPath = null;
    // this.recordMaxDurationS = null;
    isRecordReleasing = false;
    return recordPath;
  }

  Future recordRelease() async {
    logger.i("$TAG - recordRelease");
    await recordStop();
    return;
  }
}

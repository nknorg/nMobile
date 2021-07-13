import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as Player;
import 'package:flutter_sound/flutter_sound.dart' as Sound;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

class AudioHelper with Tag {
  static const double MessageRecordMaxDurationS = 30;
  static const double MessageRecordMinDurationS = 0.5;

  // player
  Player.AudioPlayer player = Player.AudioPlayer(mode: Player.PlayerMode.MEDIA_PLAYER, playerId: "AudioHelper")..setReleaseMode(Player.ReleaseMode.STOP);
  String? playerId;
  int? playerDuration; // milliSeconds

  // ignore: close_sinks
  StreamController<Map<String, dynamic>> _onPlayStateChangedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamSink<Map<String, dynamic>> get _onPlayStateChangedSink => _onPlayStateChangedController.sink;
  Stream<Map<String, dynamic>> get onPlayStateChangedStream => _onPlayStateChangedController.stream; // .distinct((prev, next) => (prev['player_id'] == next['player_id']) && (next['percent'] < prev['percent']));

  // ignore: close_sinks
  StreamController<Map<String, dynamic>> _onPlayPositionChangedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamSink<Map<String, dynamic>> get _onPlayPositionChangedSink => _onPlayPositionChangedController.sink;
  Stream<Map<String, dynamic>> get onPlayPositionChangedStream => _onPlayPositionChangedController.stream; // .distinct((prev, next) => (prev['player_id'] == next['player_id']) && (next['percent'] < prev['percent']));

  // record
  Sound.FlutterSoundRecorder record = Sound.FlutterSoundRecorder();
  String? recordId;
  String? recordPath;
  double? recordMaxDurationS;
  StreamSubscription? _onRecordProgressSubscription;

  // ignore: close_sinks
  StreamController<Map<String, dynamic>> _onRecordProgressController = StreamController<Map<String, dynamic>>.broadcast();
  StreamSink<Map<String, dynamic>> get _onRecordProgressSink => _onRecordProgressController.sink;
  Stream<Map<String, dynamic>> get onRecordProgressStream => _onRecordProgressController.stream; // .distinct((prev, next) => (prev['player_id'] == next['player_id']) && (next['percent'] < prev['percent']));

  AudioHelper() {
    // player
    Player.AudioPlayer.logEnabled = Settings.debug;
    player.onPlayerError.listen((String event) {
      logger.e("$TAG - onPlayerError - playerId:$playerId - reason:$event");
      if (playerId == null) return;
      _onPlayStateChangedSink.add({
        "id": playerId,
        "state": Player.PlayerState.STOPPED,
      });
      _onPlayPositionChangedSink.add({
        "id": playerId,
        "duration": playerDuration,
        "position": 0,
        "percent": 0,
      });
    });
    player.onPlayerStateChanged.listen((Player.PlayerState event) {
      logger.d("$TAG - onPlayerStateChanged - playerId:$playerId - state:$event");
      if (playerId == null) return;
      _onPlayStateChangedSink.add({
        "id": playerId,
        "state": event,
      });
    });
    player.onAudioPositionChanged.listen((Duration event) async {
      if (playerId == null) return;
      if (playerDuration == null) {
        int d = await player.getDuration();
        if (d > 0) playerDuration = d;
      }
      if (playerDuration == null) return;
      _onPlayPositionChangedSink.add({
        "id": playerId,
        "duration": playerDuration,
        "position": event,
        "percent": event.inMilliseconds / playerDuration!,
      });
    });
    // record
    // empty
  }

  Future<bool> playStart(String playerId, String localPath, {int? durationMs, Duration? position, bool isLocal = true}) async {
    if (player.state == Player.PlayerState.PLAYING) {
      bool isSame = playerId == this.playerId;
      await playStop();
      if (isSame) return true;
    }
    logger.d("$TAG - playStart - playerId:$playerId - localPath:$localPath - position:$position");
    this.playerId = playerId;
    this.playerDuration = durationMs;
    int result = await player.play(
      localPath,
      isLocal: isLocal,
      volume: 1,
      position: position,
    );
    return result == 1;
  }

  Future<bool> playStop() async {
    logger.d("$TAG - playStop - playerId:$playerId");
    int result = await player.stop();
    // this.playerId = null;
    // this.playerDuration = null;
    return result == 1;
  }

  Future<bool> playerRelease() async {
    bool success = await playStop();
    int result = await player.release();
    // await player.dispose();
    return success && (result == 1);
  }

  Future<String?> recordStart(String recordId, {String? savePath, double? maxDurationS, Function(RecordingDisposition)? onProgress}) async {
    logger.d("$TAG - recordStart - recordId:$recordId");
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
    if (status != PermissionStatus.granted) return null;
    // duplicated
    if (record.isRecording) {
      bool isSame = recordId == this.recordId;
      await recordStop();
      if (isSame) return null;
    }
    // save
    this.recordPath = savePath ?? await _getRecordPath();
    if (recordPath == null || recordPath!.isEmpty) return null;
    // init
    FlutterSoundRecorder? _record = await record.openAudioSession(
      category: Sound.SessionCategory.record,
    );
    if (_record == null) return null;
    record = _record;
    this.recordId = recordId;
    this.recordMaxDurationS = maxDurationS;
    // progress
    if (_onRecordProgressSubscription != null) {
      _onRecordProgressSubscription?.cancel();
    }
    _onRecordProgressSubscription = record.onProgress?.listen((RecordingDisposition event) async {
      // logger.d("$TAG - onProgress - recordId:${this.recordId} - duration:${event.duration}");
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
    await record.setSubscriptionDuration(Duration(milliseconds: 100));
    await record.startRecorder(
      toFile: recordPath,
      codec: Sound.Codec.aacADTS,
    );
    return recordPath;
  }

  Future<String?> recordStop() async {
    _onRecordProgressSubscription?.cancel();
    _onRecordProgressSubscription = null;
    await record.stopRecorder();
    await record.closeAudioSession();
    // this.recordId = null;
    // this.recordPath = null;
    // this.recordMaxDurationS = null;
    return recordPath;
  }

  Future recordRelease() async {
    await recordStop();
    return;
  }

  Future<String?> _getRecordPath() async {
    if (clientCommon.publicKey == null) return null;
    String? recordPath = Path.getCompleteFile(Path.createLocalFile(hexEncode(clientCommon.publicKey!), SubDirType.chat, "${Uuid().v4()}.aac"));
    if (recordPath == null || recordPath.isEmpty) return null;
    var outputFile = File(recordPath);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }
    await outputFile.create(recursive: true);
    return outputFile.path;
  }
}

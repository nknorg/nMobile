import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/utils/logger.dart';

class AudioHelper with Tag {
  // player
  AudioPlayer player = AudioPlayer(mode: PlayerMode.MEDIA_PLAYER, playerId: "AudioHelper")..setReleaseMode(ReleaseMode.STOP);
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

  // TODO:GG record

  AudioHelper() {
    // player
    AudioPlayer.logEnabled = Settings.debug;
    player.onPlayerError.listen((String event) {
      logger.e("$TAG - onPlayerError - playerId:$playerId - reason:$event");
      if (playerId == null) return;
      _onPlayStateChangedSink.add({
        "id": playerId,
        "state": PlayerState.STOPPED,
      });
      _onPlayPositionChangedSink.add({
        "id": playerId,
        "duration": playerDuration,
        "position": 0,
        "percent": 0,
      });
    });
    player.onPlayerStateChanged.listen((PlayerState event) {
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
  }

  Future<bool> playStart(String playerId, String localPath, {int? durationMs, Duration? position, bool isLocal = true}) async {
    if (player.state == PlayerState.PLAYING) {
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
}

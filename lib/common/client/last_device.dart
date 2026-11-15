import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/client/rpc.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/utils/hash.dart';
import 'package:nmobile/utils/logger.dart';

/// Stores last logged-in device id in NKN subscription meta (`__lst__`).
class LastDeviceCommon with Tag {
  static const String identifier = '__lst__';
  static const int _formatV1 = 1;

  String? _checkedAddress;

  void reset() {
    _checkedAddress = null;
  }

  /// Call once after client becomes connected. Shows tip when last device differs.
  Future<void> checkAfterConnected() async {
    String? address = clientCommon.address;
    Uint8List? seed = clientCommon.getSeed();
    String deviceId = Settings.deviceId;
    if ((address == null) || address.isEmpty || (seed == null) || seed.isEmpty || deviceId.isEmpty) {
      logger.w("$TAG - checkAfterConnected - missing required - address:$address - deviceId:$deviceId - seed:${seed?.length}");
      return;
    }
    if (_checkedAddress == address) {
      logger.d("$TAG - checkAfterConnected - already checked - address:$address");
      return;
    }
    _checkedAddress = address;

    try {
      String? lastDeviceId = await _getLastDeviceId(address, seed);
      bool conflict = (lastDeviceId != null) && lastDeviceId.isNotEmpty && (lastDeviceId != deviceId);
      if (conflict) {
        logger.w("$TAG - checkAfterConnected - device conflict - last:$lastDeviceId - current:$deviceId - address:$address");
        _showConflictTip();
      } else {
        logger.i("$TAG - checkAfterConnected - device ok - last:$lastDeviceId - current:$deviceId - address:$address");
      }
      if (lastDeviceId != deviceId) {
        await _setLastDeviceId(address, seed, deviceId);
      }
    } catch (e, st) {
      handleError(e, st, toast: false);
    }
  }

  Future<String?> _getLastDeviceId(String topicId, Uint8List seed) async {
    String? pubKey = clientCommon.getPublicKey() ?? topicId;
    String subscriber = '$identifier.$pubKey';
    Map<String, dynamic>? result = await RPC.getSubscription(topicId, subscriber);
    if (result == null) return null;
    String meta = result['meta']?.toString() ?? '';
    if (meta.isEmpty) return null;
    return _decryptDeviceId(meta, seed);
  }

  Future<bool> _setLastDeviceId(String topicId, Uint8List seed, String deviceId) async {
    String meta = _encryptDeviceId(deviceId, seed);
    if (meta.isEmpty) return false;
    bool success = await RPC.subscribeWithIdentifier(
      topicId,
      identifier: identifier,
      meta: meta,
      duration: Settings.blockHeightTopicSubscribe7Days,
    );
    logger.i("$TAG - _setLastDeviceId - success:$success - topicId:$topicId - deviceId:$deviceId");
    return success;
  }

  void _showConflictTip() {
    try {
      ModalDialog.of(Settings.appContext).show(
        content: Settings.locale((s) => s.tip_multi_device_same_id),
        hasCloseButton: true,
        barrierDismissible: true,
      );
    } catch (e, st) {
      handleError(e, st, toast: false);
    }
  }

  String _encryptDeviceId(String deviceId, Uint8List seed) {
    try {
      final key = enc.Key(Uint8List.fromList(Hash.sha256(seed)));
      final iv = enc.IV(_randomBytes(16));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(deviceId, iv: iv);
      final out = BytesBuilder(copy: false);
      out.addByte(_formatV1);
      out.add(iv.bytes);
      out.add(encrypted.bytes);
      return hexEncode(out.toBytes());
    } catch (e, st) {
      handleError(e, st, toast: false);
      return '';
    }
  }

  String? _decryptDeviceId(String meta, Uint8List seed) {
    try {
      // Prefer hex payload; fall back to utf8 plaintext for unexpected legacy/plaintext values.
      Uint8List all;
      try {
        all = hexDecode(meta);
      } catch (_) {
        return meta;
      }
      if (all.length < 1 + 16 + 16) return null;
      if (all[0] != _formatV1) return null;
      final key = enc.Key(Uint8List.fromList(Hash.sha256(seed)));
      final iv = enc.IV(Uint8List.fromList(all.sublist(1, 17)));
      final cipherBytes = all.sublist(17);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decrypt(enc.Encrypted(Uint8List.fromList(cipherBytes)), iv: iv);
    } catch (e, st) {
      handleError(e, st, toast: false);
      return null;
    }
  }

  Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    final b = Uint8List(length);
    for (var i = 0; i < length; i++) {
      b[i] = rnd.nextInt(256);
    }
    return b;
  }
}

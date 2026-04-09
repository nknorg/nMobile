import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:nmobile/utils/hash.dart';

class CacheEntry {
  int? invalid;
  String key;
  dynamic val;

  CacheEntry({required this.key, required this.val, this.invalid});
}

/// In-memory key/value cache plus chat drafts persisted as encrypted files under app documents.
class AppCache {
  static const int _draftFormatV1 = 1;

  // ignore: close_sinks
  StreamController<String> _draftUpdateController = StreamController<String>.broadcast();
  StreamSink<String> get _draftUpdateSink => _draftUpdateController.sink;
  Stream<String> get draftUpdateStream => _draftUpdateController.stream;

  Map<String, CacheEntry> _cacheMap = {};

  Directory? _draftsDir;

  AppCache();

  /// Call once after [Settings.init] (e.g. from [Application.registerInitialize]).
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _draftsDir = Directory(p.join(dir.path, 'drafts'));
    if (!await _draftsDir!.exists()) {
      await _draftsDir!.create(recursive: true);
    }
  }

  String _draftFilePath(String myAddress, String targetId) {
    final digest = crypto.sha256.convert(utf8.encode('$myAddress|$targetId'));
    return p.join(_draftsDir!.path, '$digest.draft');
  }

  String _draftStreamKey(String myAddress, String targetId) => '$myAddress|$targetId';

  enc.Key _aesKeyFromSeed(Uint8List seed) {
    return enc.Key(Uint8List.fromList(Hash.sha256(seed)));
  }

  
  Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    final b = Uint8List(length);
    for (var i = 0; i < length; i++) {
      b[i] = rnd.nextInt(256);
    }
    return b;
  }

  Future<void> _writeEncryptedDraft(String path, Uint8List seed, String plaintext) async {
    final key = _aesKeyFromSeed(seed);
    final iv = enc.IV(_randomBytes(16));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    final out = BytesBuilder(copy: false);
    out.addByte(_draftFormatV1);
    out.add(iv.bytes);
    out.add(encrypted.bytes);
    await File(path).writeAsBytes(out.toBytes());
  }

  String? _readEncryptedDraftFile(String path, Uint8List seed) {
    final file = File(path);
    if (!file.existsSync()) return null;
    Uint8List all;
    try {
      all = file.readAsBytesSync();
    } catch (_) {
      return null;
    }
    if (all.length < 1 + 16 + 16) return null;
    if (all[0] != _draftFormatV1) return null;
    try {
      final key = _aesKeyFromSeed(seed);
      final iv = enc.IV(Uint8List.fromList(all.sublist(1, 17)));
      final cipherBytes = all.sublist(17);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = enc.Encrypted(Uint8List.fromList(cipherBytes));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (_) {
      return null;
    }
  }

  put(String key, dynamic value) {
    CacheEntry cacheEntry = CacheEntry(key: key, val: value, invalid: 0);
    _cacheMap[key] = cacheEntry;
  }

  get(String key) {
    CacheEntry? cacheEntry = _cacheMap[key];
    if (cacheEntry == null) {
      return null;
    }
    return cacheEntry.val;
  }

  remove(String key) {
    _cacheMap.remove(key);
  }

  /// [myAddress] is the current NKN client address; [seed] is used to encrypt/decrypt file contents.
  String? getDraft(String? myAddress, String? targetId, Uint8List? seed) {
    if (myAddress == null ||
        myAddress.isEmpty ||
        targetId == null ||
        targetId.isEmpty ||
        seed == null ||
        seed.isEmpty ||
        _draftsDir == null) {
      return null;
    }
    final path = _draftFilePath(myAddress, targetId);
    final plain = _readEncryptedDraftFile(path, seed);
    if (plain == null || plain.isEmpty) return null;
    return plain;
  }

  void setDraft(String? myAddress, String? targetId, Uint8List? seed, String draft) {
    if (myAddress == null ||
        myAddress.isEmpty ||
        targetId == null ||
        targetId.isEmpty ||
        seed == null ||
        seed.isEmpty ||
        _draftsDir == null) {
      return;
    }
    final path = _draftFilePath(myAddress, targetId);
    _writeEncryptedDraft(path, seed, draft).then((_) {
      _draftUpdateSink.add(_draftStreamKey(myAddress, targetId));
    });
  }

  void removeDraft(String? myAddress, String? targetId) {
    if (myAddress == null || myAddress.isEmpty || targetId == null || targetId.isEmpty || _draftsDir == null) {
      return;
    }
    final f = File(_draftFilePath(myAddress, targetId));
    if (f.existsSync()) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
    _draftUpdateSink.add(_draftStreamKey(myAddress, targetId));
  }
}

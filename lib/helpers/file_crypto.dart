import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:path/path.dart' as p;
import 'package:synchronized/synchronized.dart';

/// AES-GCM at-rest encryption for chat files.
///
/// The AES-256 key is SHA-256 of the current NKN account seed, so it changes
/// with the account and is not stored separately.
/// Legacy files (no magic header) are left untouched and opened directly.
/// Encrypted files stay ciphertext on disk. Plaintext is written under
/// [tempDirName] only while something is reading it.
class FileCrypto {
  static const String tempDirName = 'plain_tmp';
  static const List<int> _magic = [0x4E, 0x4D, 0x47, 0x43, 0x4D, 0x30, 0x30, 0x31]; // NMGCM001
  static const int _nonceLen = 12;
  static const int _macLen = 16;
  static const int _headerLen = 8 + _nonceLen + _macLen;

  static final AesGcm _aes = AesGcm.with256bits();
  static final Lock _keyLock = Lock();
  static final Map<String, Lock> _fileLocks = <String, Lock>{};
  static final Map<String, int> _pins = <String, int>{};

  static SecretKey? _key;
  static List<int>? _keyBytes;
  static int _epoch = 0;

  /// Stored path currently handed to the audio player, if any.
  static String? playbackStored;

  static int get epoch => _epoch;

  static String tempRoot() {
    return p.join(Settings.applicationRootDirectory.path, tempDirName);
  }

  /// Wipe every restored plaintext file. Used before app UI, before a chat
  /// read session, and after leaving the chat page.
  static Future<void> clearTemp() async {
    _resetPins();
    final dir = Directory(tempRoot());
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (e, st) {
        handleError(e, st);
      }
    }
  }

  static void clearTempSync() {
    _resetPins();
    final dir = Directory(tempRoot());
    if (dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } catch (e, st) {
        handleError(e, st);
      }
    }
  }

  static void _resetPins() {
    _epoch++;
    _pins.clear();
    playbackStored = null;
  }

  static bool isEncryptedSync(String? path) {
    if (path == null || path.isEmpty) return false;
    final file = File(path);
    if (!file.existsSync()) return false;
    RandomAccessFile? raf;
    try {
      if (file.lengthSync() < _headerLen) return false;
      raf = file.openSync();
      final head = raf.readSync(_magic.length);
      if (head.length < _magic.length) return false;
      for (var i = 0; i < _magic.length; i++) {
        if (head[i] != _magic[i]) return false;
      }
      return true;
    } catch (e, st) {
      handleError(e, st);
      return false;
    } finally {
      raf?.closeSync();
    }
  }

  /// Replace [path] with AES-GCM ciphertext. Already-encrypted files are skipped
  /// so a retry cannot double-encrypt. Returns false when the plaintext is kept.
  static Future<bool> encryptInPlace(String? path) async {
    if (path == null || path.isEmpty) return false;
    final file = File(path);
    if (!file.existsSync()) return false;
    if (isEncryptedSync(path)) return true;
    final lock = _lockFor(path);
    return lock.synchronized(() async {
      if (!file.existsSync()) return false;
      if (isEncryptedSync(path)) return true;
      final tmp = File('$path.nmwriting');
      final bak = File('$path.nmbak');
      try {
        final clear = await file.readAsBytes();
        if (clear.isEmpty) return false;
        final key = await _secretKey();
        if (key == null) return false;
        final box = await _aes.encrypt(clear, secretKey: key);
        await tmp.writeAsBytes(_pack(box), flush: true);
        if (bak.existsSync()) await bak.delete();
        await file.rename(bak.path);
        await tmp.rename(path);
        if (bak.existsSync()) await bak.delete();
        return true;
      } catch (e, st) {
        handleError(e, st);
        try {
          if (!file.existsSync() && bak.existsSync()) {
            await bak.rename(path);
          }
          if (tmp.existsSync()) await tmp.delete();
          if (bak.existsSync() && file.existsSync()) await bak.delete();
        } catch (e2, st2) {
          handleError(e2, st2);
        }
        return false;
      }
    });
  }

  /// Plain path for viewing. Legacy files return [storedPath]. Encrypted files
  /// are restored into the temp folder. The previous plaintext of this file is
  /// removed before a fresh restore when nobody else is still reading it.
  static Future<String?> openForRead(String? storedPath) async {
    if (storedPath == null || storedPath.isEmpty) return storedPath;
    final src = File(storedPath);
    if (!src.existsSync()) return storedPath;
    if (!isEncryptedSync(storedPath)) return storedPath;

    final epoch = _epoch;
    final lock = _lockFor(storedPath);
    return lock.synchronized(() async {
      if (epoch != _epoch) return null;
      final dest = _destFor(storedPath);
      final destFile = File(dest);
      final refs = _pins[storedPath] ?? 0;
      if (refs > 0 && destFile.existsSync()) {
        _pins[storedPath] = refs + 1;
        return dest;
      }
      if (destFile.existsSync()) {
        try {
          destFile.deleteSync();
        } catch (e, st) {
          handleError(e, st);
        }
      }
      try {
        await _decryptTo(storedPath, dest);
      } catch (e, st) {
        handleError(e, st);
        if (destFile.existsSync()) {
          try {
            destFile.deleteSync();
          } catch (_) {}
        }
        return null;
      }
      if (epoch != _epoch) {
        final written = File(dest);
        if (written.existsSync()) {
          try {
            written.deleteSync();
          } catch (_) {}
        }
        return null;
      }
      _pins[storedPath] = refs + 1;
      if ((_pins[storedPath] ?? 0) < 1) _pins[storedPath] = 1;
      return dest;
    });
  }

  /// Original bytes. Legacy files are read directly. Encrypted files are restored
  /// only for this read, then the temp copy is released.
  static Future<Uint8List?> readPlainBytes(String? path) async {
    final plain = await openForRead(path);
    if (plain == null || plain.isEmpty) return null;
    try {
      final file = File(plain);
      if (!file.existsSync()) return null;
      return await file.readAsBytes();
    } finally {
      if (plain != path) await release(path);
    }
  }

  /// Drop one reader. The restored file is deleted when the last reader finishes.
  static Future<void> release(String? storedPath) async {
    if (storedPath == null || storedPath.isEmpty) return;
    if (!isEncryptedSync(storedPath) && !_pins.containsKey(storedPath)) return;
    final lock = _lockFor(storedPath);
    await lock.synchronized(() async {
      final refs = _pins[storedPath];
      if (refs == null) return;
      if (refs <= 1) {
        _pins.remove(storedPath);
        final dest = File(_destFor(storedPath));
        if (dest.existsSync()) {
          try {
            await dest.delete();
          } catch (e, st) {
            handleError(e, st);
          }
        }
      } else {
        _pins[storedPath] = refs - 1;
      }
    });
  }

  static Future<void> playbackFinished(String? storedPath) async {
    if (playbackStored == storedPath) playbackStored = null;
    await release(storedPath);
  }

  static Future<void> releasePlayback() async {
    final stored = playbackStored;
    playbackStored = null;
    if (stored != null) await release(stored);
  }

  /// AES-256 key is SHA-256 of the current NKN account seed.
  /// A different account produces a different key.
  static Future<SecretKey?> _secretKey() {
    return _keyLock.synchronized(() async {
      final seed = await _accountSeed();
      if (seed == null || seed.isEmpty) {
        logger.w('FileCrypto - account seed is empty');
        return null;
      }
      final keyBytes = sha256.convert(seed).bytes;
      if (_key != null && _keyBytes != null && _sameBytes(_keyBytes!, keyBytes)) {
        return _key;
      }
      _keyBytes = keyBytes;
      _key = SecretKey(keyBytes);
      return _key;
    });
  }

  static Future<Uint8List?> _accountSeed() async {
    final live = clientCommon.getSeed();
    if (live != null && live.isNotEmpty) return Uint8List.fromList(live);
    String? address = clientCommon.address;
    if (address == null || address.isEmpty) {
      address = await walletCommon.getDefaultAddress();
    }
    if (address == null || address.isEmpty) return null;
    final stored = await walletCommon.getSeed(address);
    if (stored is! String || stored.isEmpty) return null;
    try {
      final bytes = hexDecode(stored);
      if (bytes.isEmpty) return null;
      return bytes;
    } catch (e, st) {
      handleError(e, st);
      return null;
    }
  }

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static Uint8List _pack(SecretBox box) {
    final nonce = box.nonce;
    final mac = box.mac.bytes;
    final cipher = box.cipherText;
    if (nonce.length != _nonceLen || mac.length != _macLen) {
      throw StateError('unexpected AES-GCM nonce/mac length');
    }
    final out = Uint8List(_headerLen + cipher.length);
    out.setRange(0, _magic.length, _magic);
    out.setRange(_magic.length, _magic.length + _nonceLen, nonce);
    out.setRange(_magic.length + _nonceLen, _headerLen, mac);
    out.setRange(_headerLen, out.length, cipher);
    return out;
  }

  static Future<void> _decryptTo(String src, String dest) async {
    final bytes = await File(src).readAsBytes();
    if (bytes.length < _headerLen) {
      throw StateError('encrypted file is truncated');
    }
    final nonce = bytes.sublist(_magic.length, _magic.length + _nonceLen);
    final mac = bytes.sublist(_magic.length + _nonceLen, _headerLen);
    final cipher = bytes.sublist(_headerLen);
    final key = await _secretKey();
    if (key == null) {
      throw StateError('nkn account seed is empty');
    }
    final clear = await _aes.decrypt(
      SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
      secretKey: key,
    );
    final out = File(dest);
    await out.parent.create(recursive: true);
    final writing = File('$dest.writing');
    await writing.writeAsBytes(clear, flush: true);
    if (out.existsSync()) await out.delete();
    await writing.rename(dest);
  }

  static String _destFor(String storedPath) {
    final ext = p.extension(storedPath);
    final name = sha256.convert(utf8.encode(storedPath)).toString();
    return p.join(tempRoot(), '$name$ext');
  }

  static Lock _lockFor(String path) {
    return _fileLocks.putIfAbsent(path, () => Lock());
  }
}

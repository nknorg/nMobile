import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/components/dialog/apk_upgrade_notes.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/plugins/apk_installer.dart';
import 'package:nmobile/utils/nlog_util.dart';

class UpgradeChecker {
  static final _localStore = LocalStorage();

  static bool get _isAndroid => Platform.isAndroid;

  static bool get _isRelease => Global.isRelease;

  static String get _currentVer => Global.versionFull; // 1.0.1-pro + (Build 101);

  static bool _dialogShowing = false;
  static bool _forGenSh1 = false;

  static void setDialogDismissed() {
    _dialogShowing = false;
  }

  static Future<int> _getPrevTimeMillis() async {
    return await _localStore.get(LocalStorage.APP_UPGRADED_PREV_TIME_MILLIS);
  }

  static void _setPrevTimeMillis() async {
    await _localStore.set(LocalStorage.APP_UPGRADED_PREV_TIME_MILLIS, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<bool> _isVersionIgnored(String version) async {
    String versionIgnored = await _localStore.get(LocalStorage.APP_UPGRADED_VERSION_IGNORED);
    print('_isVersionIgnored version: $versionIgnored');
    return versionIgnored != null && versionIgnored == version;
  }

  static void setVersionIgnored(String version) async {
    setDialogDismissed();
    print('setVersionIgnoredOrInstalled version: $version');
    await _localStore.set(LocalStorage.APP_UPGRADED_VERSION_IGNORED, version);
  }

  static Future<bool> _isVersionCoverGatedLaunch(String version, double gatedLaunch) async {
    print('_isVersionCoverGatedLaunch --->');
    String versionedGatedLaunch = await _localStore.get(LocalStorage.APP_UPGRADED_GATED_LAUNCH_WITH_VERSION);
    if (versionedGatedLaunch != null) {
      List<String> list = versionedGatedLaunch.split(':');
      if (list.length == 2) {
        try {
          String ver = list[0];
          double gl = double.tryParse(list[1]);
          print('_isVersionCoverGatedLaunch versionLocal: $ver, versionCode: $version');
          print('_isVersionCoverGatedLaunch gatedLaLocal: $gl, gatedLaunch: $gatedLaunch');
          if (ver == version && gl <= gatedLaunch) {
            return true;
          }
        } catch (e) {}
      }
    }
    double gatedLa = _random();
    await _localStore.set(LocalStorage.APP_UPGRADED_GATED_LAUNCH_WITH_VERSION, '$version:$gatedLa');
    return gatedLa <= gatedLaunch;
  }

  static double _random() {
    final random = Random.secure();
    int max = random.nextInt(100);
    double randomDouble;
    for (var n = 0; n < max; n++) {
      randomDouble = random.nextDouble();
    }
    if (randomDouble == null) randomDouble = random.nextDouble();
    return randomDouble;
  }

  static bool _isNowAfterOneDay(DateTime prev) {
    var now = DateTime.now();
    return now.year > prev.year || now.year == prev.year && (now.month > prev.month || now.month == prev.month && now.day > prev.day);
  }

  static void autoCheckUpgrade(BuildContext context) async {
    print('autoCheckUpgrade --> isAndroid: $_isAndroid');
    if (!_isAndroid || _dialogShowing) return;
    var prevTime = await _getPrevTimeMillis();
    var prev = prevTime == null ? null : DateTime.fromMillisecondsSinceEpoch(prevTime);
    if (_forGenSh1 || prev == null || _isNowAfterOneDay(prev)) {
      print('autoCheckUpgrade --> checkUpgrade...');
      checkUpgrade(context, true, (version, title, notes, force, jsonMap) {
        var bloc;
        bloc = ApkUpgradeNotesDialog.of(context).show(version, title, notes, force, jsonMap, (jsonMap) {
          downloadApkFile(jsonMap, (progress) {
            bloc.add(progress);
          });
        }, (version) {
          setVersionIgnored(version);
        }, () {
          setDialogDismissed();
        });
      });
    }
  }

  /*{
  "apkUrl": "https://github.com/nknorg/${apk-url}.apk",
  "version": "1.0.1-pro",
  "gatedLaunch": 0.1,
  "notes": "${markdown}",
  "sha-1": "${hash by sha-1}",
  "force": false
  }*/
  static void checkUpgrade(BuildContext context, bool auto, onShowNotes(String version, String title, String notes, bool force, Map jsonMap), {VoidCallback onAlreadyTheLatestVersion}) async {
    assert(_isAndroid);

    bool _isZh = Global.isLocaleZh();
    _dio.get(_forGenSh1 ? UPGRADE_PROFILE_URL_gen_sha1 : _isZh ? UPGRADE_PROFILE_URL_zh : UPGRADE_PROFILE_URL, queryParameters: _forGenSh1 ? {"v": _random().toStringAsFixed(5)} : {}).then((resp) async {
      if (resp.statusCode == HttpStatus.ok) {
        final jsonMap = jsonDecode(resp.data);
        final String apkUrl = jsonMap['apkUrl'];
        final String version = jsonMap['version'];
        final double gatedLaunch = jsonMap['gatedLaunch'];
        final String title = jsonMap['title'];
        final String notes = jsonMap['notes'];
        final String sha1Hash = jsonMap['sha-1'];
        final bool force = jsonMap['force'];

        NLog.v('apkUrl: $apkUrl', tag: 'upgrade.profile');
        NLog.v('version: $version', tag: 'upgrade.profile');
        NLog.v('gatedLaunch: $gatedLaunch', tag: 'upgrade.profile');
        //LogUtil.v('notes: $notes', tag: 'upgrade.profile');
        NLog.v('sha-1: $sha1Hash', tag: 'upgrade.profile');
        NLog.v('force: $force', tag: 'upgrade.profile');

        if (_forGenSh1) {
          if (!_dialogShowing) {
            _dialogShowing = true;
            onShowNotes(version, title, notes, force, jsonMap);
          }
        } else if (version.compareTo(_currentVer) <= 0) {
          if (onAlreadyTheLatestVersion != null) onAlreadyTheLatestVersion();
        } else {
          bool isIgnored = await _isVersionIgnored(version);
          bool isCurrVerCoverGatedL = await _isVersionCoverGatedLaunch(version, gatedLaunch);
          if ((force || !auto || !isIgnored) && isCurrVerCoverGatedL && !_dialogShowing) {
            print('_isVersionCoverGatedLaunch: true');
            _dialogShowing = true;
            onShowNotes(version, title, notes, force, jsonMap);
            if (!force) _setPrevTimeMillis();
          }
        }
      }
    });
  }

  static void downloadApkFile(Map jsonMap, onProgress(double progress)) async {
    // setDialogDismissed();
    final String apkUrl = jsonMap['apkUrl'];
    final String sha1Hash = jsonMap['sha-1'];
    final String version = jsonMap['version'];

    final apkCachePath = await createApkCachePath(apkUrl);
    print('apkCachePath: $apkCachePath');
    if (await _checkApkFile(apkCachePath, sha1Hash)) {
      print('_checkApkFile, Done.==================');
      ApkInstallerPlugin.ins().installApk(apkCachePath);
      return;
    }
    final tmpFile = File(apkCachePath + '.tmp');
    NLog.v('tmpFile: ${tmpFile.path}', tag: 'upgrade.profile');
    _dio.download(apkUrl, tmpFile.path, queryParameters: {'version': version}, onReceiveProgress: (received, total) {
      if (total > 0) {
        onProgress(received / total);
      }
    }).then((resp) async {
      var apkFile = tmpFile.renameSync(apkCachePath);
      NLog.v('resp.data:${resp.data}', tag: 'upgrade.profile');
      NLog.v('apkFile:${apkFile.path}', tag: 'upgrade.profile');
      if (await _checkApkFile(apkCachePath, sha1Hash)) {
        print('_checkApkFile 2, Done.==================');
        ApkInstallerPlugin.ins().installApk(apkCachePath);
      }
    });
  }

  static Future<bool> _checkApkFile(String path, String sha1) async {
    _deleteApksExcept(path);
    var f = File(path);
    if (f.existsSync()) {
      final sha1f = await sha1File(f);
      print('apk file sha1: $sha1f');
      if (sha1 == sha1f) {
        return true;
      } else {
        f.deleteSync();
        return false;
      }
    }
    return false;
  }

  static void _deleteApksExcept(String path) {
    var list = File(path).parent.listSync(recursive: true, followLinks: true);
    for (var tmp in list) {
      if (tmp.path != path) {
        tmp.deleteSync(recursive: true);
        print('_deleteApksExcept deleteSync: $tmp');
      }
    }
  }

  static final _dio = Dio(BaseOptions(
    baseUrl: _isRelease ? UPGRADE_BASE_URL : UPGRADE_BASE_URL,
    connectTimeout: 30000,
    receiveTimeout: -1,
    headers: {HttpHeaders.userAgentHeader: 'dio', 'common-header': 'xxx'},
  ));

  static final String UPGRADE_BASE_URL = 'https://nmobile.nkn.org/upgrade/pro/';
  static final String UPGRADE_PROFILE_URL = 'upgrade.profile';
  static final String UPGRADE_PROFILE_URL_zh = 'upgrade.profile.zh';
  static final String UPGRADE_PROFILE_URL_gen_sha1 = 'upgrade.profile.gen.sha1';
}

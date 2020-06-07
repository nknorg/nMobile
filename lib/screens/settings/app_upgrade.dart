import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:common_utils/common_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/components/dialog/apk_upgrade_notes.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/plugins/apk_installer.dart';
import 'package:oktoast/oktoast.dart';

class UpgradeChecker {
  static final _localStore = LocalStorage();

  static bool get _isAndroid => Platform.isAndroid;

  static bool get _isRelease => Global.isRelease;

  static int get _currentVerCode => 0; // TODO: // Global.version // 1.0.1-pro;

  static Future<int> _getPrevTimeMillis() async {
    return await _localStore.get(LocalStorage.APP_UPGRADED_PREV_TIME_MILLIS);
  }

  static void _setPrevTimeMillis() async {
    await _localStore.set(LocalStorage.APP_UPGRADED_PREV_TIME_MILLIS, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<bool> _isThisVersionIgnoredOrInstalled(int versionCode) async {
    int versionIgnoreOrInstalled = await _localStore.get(LocalStorage.APP_UPGRADED_VERSION_IGNORED_OR_INSTALLED);
    print('_isThisVersionIgnoredOrInstalled version: $versionIgnoreOrInstalled');
    return versionIgnoreOrInstalled != null && versionIgnoreOrInstalled == versionCode;
  }

  static void setVersionIgnoredOrInstalled(int versionCode) async {
    print('setVersionIgnoredOrInstalled version: $versionCode');
    await _localStore.set(LocalStorage.APP_UPGRADED_VERSION_IGNORED_OR_INSTALLED, versionCode);
  }

  static Future<bool> _isCurrVerCoverGatedLaunch(int versionCode, double gatedLaunch) async {
    print('_isCurrVerCoverGatedLaunch --->');
    String versionedGatedLaunch = await _localStore.get(LocalStorage.APP_UPGRADED_GATED_LAUNCH_WITH_VERSION);
    if (versionedGatedLaunch != null) {
      List<String> list = versionedGatedLaunch.split(':');
      if (list.length == 2) {
        try {
          int ver = int.tryParse(list[0]);
          double gl = double.tryParse(list[1]);
          print('_isCurrVerCoverGatedLaunch versionLocal: $ver, versionCode: $versionCode');
          print('_isCurrVerCoverGatedLaunch gatedLaLocal: $gl, gatedLaunch: $gatedLaunch');
          if (ver == versionCode && gl <= gatedLaunch) {
            return true;
          }
        } catch (e) {}
      }
    }
    double gatedLa = _random();
    await _localStore.set(LocalStorage.APP_UPGRADED_GATED_LAUNCH_WITH_VERSION, '$versionCode:$gatedLa');
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
    if (!_isAndroid) return;
    var prevTime = await _getPrevTimeMillis();
    var prev = prevTime == null ? null : DateTime.fromMillisecondsSinceEpoch(prevTime);
    if (prev == null || _isNowAfterOneDay(prev)) {
      checkUpgrade(context, (showNotes, versionCode, title, notes, force, jsonMap) {
        if (showNotes) {
          ApkUpgradeNotesDialog.of(context).show(versionCode, title, notes, force, jsonMap, (jsonMap) {
            downloadApkFile(jsonMap, (progress) {
              // TODO:
              print('downloadApkFile progress: $progress%');
            });
          }, (versionCode) {
            setVersionIgnoredOrInstalled(versionCode);
          });
        }
      });
    }
  }

  /*{
  "apkUrl": "https://github.com/nknorg/${apk-url}.apk",
  "version": ${versionCode},
  "gatedLaunch": 0.1,
  "notes": "${markdown}",
  "sha-1": "${hash by sha-1}",
  "force": false
  }*/
  static void checkUpgrade(BuildContext context, onShowNotes(bool showNotes, int versionCode, String title, String notes, bool force, Map jsonMap)) async {
    assert(_isAndroid);
    showToast(NMobileLocalizations.of(context).check_upgrade, duration: Duration(seconds: 5));

    bool _isZh = Global.isLocaleZh();
    _dio.get(_isZh ? UPGRADE_PROFILE_URL_zh : UPGRADE_PROFILE_URL).then((resp) async {
      if (resp.statusCode == HttpStatus.ok) {
        _setPrevTimeMillis();
        final jsonMap = jsonDecode(resp.data);
        final String apkUrl = jsonMap['apkUrl'];
        final int versionCode = jsonMap['version'];
        final double gatedLaunch = jsonMap['gatedLaunch'];
        final String title = jsonMap['title'];
        final String notes = jsonMap['notes'];
        final String sha1Hash = jsonMap['sha-1'];
        final bool force = jsonMap['force'];

        LogUtil.v('apkUrl: $apkUrl', tag: 'upgrade.profile');
        LogUtil.v('version: $versionCode', tag: 'upgrade.profile');
        LogUtil.v('gatedLaunch: $gatedLaunch', tag: 'upgrade.profile');
        //LogUtil.v('notes: $notes', tag: 'upgrade.profile');
        LogUtil.v('sha-1: $sha1Hash}', tag: 'upgrade.profile');
        LogUtil.v('force: $force}', tag: 'upgrade.profile');

        bool isIgnoredOrInstalled = await _isThisVersionIgnoredOrInstalled(versionCode);
        bool isCurrVerCoverGatedL = await _isCurrVerCoverGatedLaunch(versionCode, gatedLaunch);
        if (versionCode != _currentVerCode && (!_isRelease || !isIgnoredOrInstalled) && isCurrVerCoverGatedL) {
          print('_isCurrVerCoverGatedLaunch: true');
          onShowNotes(true, versionCode, title, notes, force, jsonMap);
        }
      }
    });
  }

  static void downloadApkFile(Map jsonMap, onProgress(String progress)) async {
    final String apkUrl = jsonMap['apkUrl'];
    final String sha1Hash = jsonMap['sha-1'];
    final int versionCode = jsonMap['version'];

    final apkCachePath = createApkCachePath(apkUrl);
    print('apkCachePath: $apkCachePath');
    if (await _checkApkFile(apkCachePath, sha1Hash)) {
      print('_checkApkFile, Done.==================');
      ApkInstallerPlugin.ins().installApk(apkCachePath);
      return;
    }
    final tmpFile = File(apkCachePath + '.tmp');
    LogUtil.v('apkCachePath:${tmpFile.path}', tag: 'upgrade.profile');
    _dio.download(apkUrl, tmpFile.path, queryParameters: {'version': versionCode}, onReceiveProgress: (received, total) {
      if (total != -1) {
        String progress = (received / total * 100).toStringAsFixed(0);
        onProgress(progress);
      }
    }).then((resp) async {
      var apkFile = tmpFile.renameSync(apkCachePath);
      LogUtil.v('resp.data:${resp.data}', tag: 'upgrade.profile');
      LogUtil.v('apkFile:${apkFile.path}', tag: 'upgrade.profile');
      if (await _checkApkFile(apkCachePath, sha1Hash)) {
        print('_checkApkFile 2, Done.==================');
        ApkInstallerPlugin.ins().installApk(apkCachePath);
      }
    });
  }

  static Future<bool> _checkApkFile(String path, String sha1) async {
    var f = File(path);
    if (f.existsSync()) {
      final sha1f = await sha1File(f);
      print('sha1File: $sha1f');
      if (sha1 == sha1f) {
        return true;
      } else {
        f.deleteSync();
        return false;
      }
    }
    return false;
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
}

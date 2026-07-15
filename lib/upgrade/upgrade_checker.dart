import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/modal.dart';
import 'package:nmobile/storages/settings.dart' as settings_storage;
import 'package:nmobile/utils/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:store_checker/store_checker.dart';
import 'package:version/version.dart';

import '../utils/util.dart';
import 'appcast_model.dart';

class UpgradeChecker {
  static const String _appcastUrl = 'https://nmobile-releases.nkn.org/upgrade/appcast.json';
  static const String _ignoreKey = 'upgrade_ignore_timestamp';
  static const int _ignoreDurationHours = 24; // 24h
  static bool _hasChecked = false;

  static Future<void> checkAndShowDialog(BuildContext context) async {
    print('UpgradeChecker - checkAndShowDialog - start');
    if (_hasChecked) return;
    _hasChecked = true;

    if (await _isIgnoredRecently()) {
      logger.i('UpgradeChecker - checkAndShowDialog - ignored recently, skip');
      return;
    }

    try {
      final dio = Dio();
      final response = await dio.get(_appcastUrl);

      if (response.statusCode == 200) {
        final appcast = AppcastModel.fromJson(response.data);
        final packageInfo = await PackageInfo.fromPlatform();
        Version currentVersion = Version.parse(packageInfo.version);
        Version minVersion = Version.parse(appcast.minVersion);

        logger.i('UpgradeChecker - checkAndShowDialog - currentVersion: $currentVersion, minVersion: $minVersion');
        if (minVersion > currentVersion) {
          _showUpgradeDialog(context, appcast);
        }
      }
    } catch (e, st) {
      logger.w('UpgradeChecker - checkAndShowDialog - error: $e');
      logger.w('UpgradeChecker - checkAndShowDialog - stack: $st');
    }
  }

  static Future<bool> _isIgnoredRecently() async {
    try {
      final ignoreTimestamp = await settings_storage.SettingsStorage.getSettings(_ignoreKey);
      if (ignoreTimestamp == null) return false;

      final timestamp = ignoreTimestamp is int ? ignoreTimestamp : int.tryParse(ignoreTimestamp.toString());
      if (timestamp == null) return false;

      final now = DateTime.now().millisecondsSinceEpoch;
      final diffHours = (now - timestamp) / (1000 * 60 * 60);

      return diffHours < _ignoreDurationHours;
    } catch (e) {
      logger.w('UpgradeChecker - _isIgnoredRecently - error: $e');
      return false;
    }
  }

  static Future<void> _recordIgnore() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await settings_storage.SettingsStorage.setSettings(_ignoreKey, timestamp);
      logger.i('UpgradeChecker - _recordIgnore - timestamp: $timestamp');
    } catch (e) {
      logger.w('UpgradeChecker - _recordIgnore - error: $e');
    }
  }

  static void _showUpgradeDialog(BuildContext context, AppcastModel appcast) {
    final locale = Localizations.localeOf(context);
    final localeCode = locale;
    logger.i('UpgradeChecker - _showUpgradeDialog - locale: $localeCode');
    String releaseNotes = '';
    switch (localeCode.toString()) {
      case 'zh':
      case 'zh_CN':
        releaseNotes = appcast.releaseNotes['zh'] ?? '';
        break;
      case 'zh_TW':
      case 'zh-TW':
        releaseNotes = appcast.releaseNotes['zh-TW'] ?? '';
        break;
      case 'en':
        releaseNotes = appcast.releaseNotes['en'] ?? '';
        break;
      default:
        releaseNotes = appcast.releaseNotes['en'] ?? '';
        break;
    }

    final content = releaseNotes.isNotEmpty
        ? '${Settings.locale((s) => s.version, ctx: context)}: ${appcast.latestVersion}\n\n$releaseNotes'
        : '${Settings.locale((s) => s.version, ctx: context)}: ${appcast.latestVersion}';

    final dialog = ModalDialog.of(context);
    dialog.show(
      title: '${Settings.locale((s) => s.update_app, ctx: context)}?',
      content: content,
      hasCloseButton: false,
      hasCloseIcon: false,
      barrierDismissible: false,
      actions: [
        Button(
          backgroundColor: application.theme.primaryColor,
          fontColor: Colors.white,
          text: Settings.locale((s) => s.ok, ctx: context),
          width: double.infinity,
          onPressed: () async {
            Navigator.of(context).pop();
            await _handleUpdate(appcast);
          },
        ),
        Button(
          backgroundColor: application.theme.backgroundLightColor,
          fontColor: application.theme.fontColor2,
          text: Settings.locale((s) => s.ignore, ctx: context),
          width: double.infinity,
          onPressed: () async {
            Navigator.of(context).pop();
            await _recordIgnore();
          },
        ),
      ],
    );
  }

  static Future<void> _handleUpdate(AppcastModel appcast) async {
    String? updateUrl;

    try {
      final source = await StoreChecker.getSource;
      logger.i('UpgradeChecker - _handleUpdate - source: $source');

      if (Platform.isIOS) {
        updateUrl = appcast.links.ios;
      } else if (Platform.isAndroid) {
        if (source == Source.IS_INSTALLED_FROM_PLAY_STORE) {
          updateUrl = appcast.links.androidPlay;
        } else {
          updateUrl = appcast.links.androidApk;
        }
      }

      logger.i('UpgradeChecker - _handleUpdate - updateUrl: $updateUrl');
      if (updateUrl != null && updateUrl.isNotEmpty) {
        Util.launchUrl(updateUrl);
      }
    } catch (e, st) {
      logger.w('UpgradeChecker - _handleUpdate - error: $e');
      logger.w('UpgradeChecker - _handleUpdate - stack: $st');
    }
  }
}

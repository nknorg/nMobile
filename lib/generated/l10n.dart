// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values

class S {
  S();
  
  static S current;
  
  static const AppLocalizationDelegate delegate =
    AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false) ? locale.languageCode : locale.toString();
    final localeName = Intl.canonicalizedLocale(name); 
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      S.current = S();
      
      return S.current;
    });
  } 

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `nMobile`
  String get app_name {
    return Intl.message(
      'nMobile',
      name: 'app_name',
      desc: '',
      args: [],
    );
  }

  /// `D-Chat`
  String get d_chat {
    return Intl.message(
      'D-Chat',
      name: 'd_chat',
      desc: '',
      args: [],
    );
  }

  /// `Home`
  String get menu_home {
    return Intl.message(
      'Home',
      name: 'menu_home',
      desc: '',
      args: [],
    );
  }

  /// `D-Chat`
  String get menu_chat {
    return Intl.message(
      'D-Chat',
      name: 'menu_chat',
      desc: '',
      args: [],
    );
  }

  /// `Settings`
  String get menu_settings {
    return Intl.message(
      'Settings',
      name: 'menu_settings',
      desc: '',
      args: [],
    );
  }

  /// `Account`
  String get menu_wallet {
    return Intl.message(
      'Account',
      name: 'menu_wallet',
      desc: '',
      args: [],
    );
  }

  /// `News`
  String get menu_news {
    return Intl.message(
      'News',
      name: 'menu_news',
      desc: '',
      args: [],
    );
  }

  /// `OK`
  String get ok {
    return Intl.message(
      'OK',
      name: 'ok',
      desc: '',
      args: [],
    );
  }

  /// `Delete`
  String get delete {
    return Intl.message(
      'Delete',
      name: 'delete',
      desc: '',
      args: [],
    );
  }

  /// `Cancel`
  String get cancel {
    return Intl.message(
      'Cancel',
      name: 'cancel',
      desc: '',
      args: [],
    );
  }

  /// `Close`
  String get close {
    return Intl.message(
      'Close',
      name: 'close',
      desc: '',
      args: [],
    );
  }

  /// `Back`
  String get back {
    return Intl.message(
      'Back',
      name: 'back',
      desc: '',
      args: [],
    );
  }

  /// `Agree`
  String get agree {
    return Intl.message(
      'Agree',
      name: 'agree',
      desc: '',
      args: [],
    );
  }

  /// `Reject`
  String get reject {
    return Intl.message(
      'Reject',
      name: 'reject',
      desc: '',
      args: [],
    );
  }

  /// `Warning`
  String get warning {
    return Intl.message(
      'Warning',
      name: 'warning',
      desc: '',
      args: [],
    );
  }

  /// `Save`
  String get save {
    return Intl.message(
      'Save',
      name: 'save',
      desc: '',
      args: [],
    );
  }

  /// `Name`
  String get name {
    return Intl.message(
      'Name',
      name: 'name',
      desc: '',
      args: [],
    );
  }

  /// `Loading`
  String get loading {
    return Intl.message(
      'Loading',
      name: 'loading',
      desc: '',
      args: [],
    );
  }

  /// `Connect`
  String get connect {
    return Intl.message(
      'Connect',
      name: 'connect',
      desc: '',
      args: [],
    );
  }

  /// `Connected`
  String get connected {
    return Intl.message(
      'Connected',
      name: 'connected',
      desc: '',
      args: [],
    );
  }

  /// `Connecting`
  String get connecting {
    return Intl.message(
      'Connecting',
      name: 'connecting',
      desc: '',
      args: [],
    );
  }

  /// `Disconnect`
  String get disconnect {
    return Intl.message(
      'Disconnect',
      name: 'disconnect',
      desc: '',
      args: [],
    );
  }

  /// `Tips`
  String get tips {
    return Intl.message(
      'Tips',
      name: 'tips',
      desc: '',
      args: [],
    );
  }

  /// `General`
  String get general {
    return Intl.message(
      'General',
      name: 'general',
      desc: '',
      args: [],
    );
  }

  /// `Language`
  String get language {
    return Intl.message(
      'Language',
      name: 'language',
      desc: '',
      args: [],
    );
  }

  /// `Auto`
  String get language_auto {
    return Intl.message(
      'Auto',
      name: 'language_auto',
      desc: '',
      args: [],
    );
  }

  /// `Change Language`
  String get change_language {
    return Intl.message(
      'Change Language',
      name: 'change_language',
      desc: '',
      args: [],
    );
  }

  /// `Scan`
  String get scan {
    return Intl.message(
      'Scan',
      name: 'scan',
      desc: '',
      args: [],
    );
  }

  /// `About`
  String get about {
    return Intl.message(
      'About',
      name: 'about',
      desc: '',
      args: [],
    );
  }

  /// `Version`
  String get version {
    return Intl.message(
      'Version',
      name: 'version',
      desc: '',
      args: [],
    );
  }

  /// `Help`
  String get help {
    return Intl.message(
      'Help',
      name: 'help',
      desc: '',
      args: [],
    );
  }

  /// `Contact`
  String get contact_us {
    return Intl.message(
      'Contact',
      name: 'contact_us',
      desc: '',
      args: [],
    );
  }

  /// `Security`
  String get security {
    return Intl.message(
      'Security',
      name: 'security',
      desc: '',
      args: [],
    );
  }

  /// `Face ID`
  String get face_id {
    return Intl.message(
      'Face ID',
      name: 'face_id',
      desc: '',
      args: [],
    );
  }

  /// `Touch ID`
  String get touch_id {
    return Intl.message(
      'Touch ID',
      name: 'touch_id',
      desc: '',
      args: [],
    );
  }

  /// `Notification`
  String get notification {
    return Intl.message(
      'Notification',
      name: 'notification',
      desc: '',
      args: [],
    );
  }

  /// `Notification Type`
  String get notification_type {
    return Intl.message(
      'Notification Type',
      name: 'notification_type',
      desc: '',
      args: [],
    );
  }

  /// `Local Notification`
  String get local_notification {
    return Intl.message(
      'Local Notification',
      name: 'local_notification',
      desc: '',
      args: [],
    );
  }

  /// `Only display name`
  String get local_notification_only_name {
    return Intl.message(
      'Only display name',
      name: 'local_notification_only_name',
      desc: '',
      args: [],
    );
  }

  /// `Display name and message`
  String get local_notification_both_name_message {
    return Intl.message(
      'Display name and message',
      name: 'local_notification_both_name_message',
      desc: '',
      args: [],
    );
  }

  /// `None display`
  String get local_notification_none_display {
    return Intl.message(
      'None display',
      name: 'local_notification_none_display',
      desc: '',
      args: [],
    );
  }

  /// `Notification Sound`
  String get notification_sound {
    return Intl.message(
      'Notification Sound',
      name: 'notification_sound',
      desc: '',
      args: [],
    );
  }

  /// `Advanced`
  String get advanced {
    return Intl.message(
      'Advanced',
      name: 'advanced',
      desc: '',
      args: [],
    );
  }

  /// `Cache`
  String get cache {
    return Intl.message(
      'Cache',
      name: 'cache',
      desc: '',
      args: [],
    );
  }

  /// `Clear Cache`
  String get clear_cache {
    return Intl.message(
      'Clear Cache',
      name: 'clear_cache',
      desc: '',
      args: [],
    );
  }

  /// `Clear Database`
  String get clear_database {
    return Intl.message(
      'Clear Database',
      name: 'clear_database',
      desc: '',
      args: [],
    );
  }

  /// `Account Name`
  String get wallet_name {
    return Intl.message(
      'Account Name',
      name: 'wallet_name',
      desc: '',
      args: [],
    );
  }

  /// `Enter wallet name`
  String get hint_enter_wallet_name {
    return Intl.message(
      'Enter wallet name',
      name: 'hint_enter_wallet_name',
      desc: '',
      args: [],
    );
  }

  /// `Password`
  String get wallet_password {
    return Intl.message(
      'Password',
      name: 'wallet_password',
      desc: '',
      args: [],
    );
  }

  /// `Enter your local password`
  String get input_password {
    return Intl.message(
      'Enter your local password',
      name: 'input_password',
      desc: '',
      args: [],
    );
  }

  /// `Your password must be at least 8 characters. It is recommended to use a mix of different characters.`
  String get wallet_password_mach {
    return Intl.message(
      'Your password must be at least 8 characters. It is recommended to use a mix of different characters.',
      name: 'wallet_password_mach',
      desc: '',
      args: [],
    );
  }

  /// `Confirm Password`
  String get confirm_password {
    return Intl.message(
      'Confirm Password',
      name: 'confirm_password',
      desc: '',
      args: [],
    );
  }

  /// `Enter your password again`
  String get input_password_again {
    return Intl.message(
      'Enter your password again',
      name: 'input_password_again',
      desc: '',
      args: [],
    );
  }

  /// `Create Account`
  String get create_wallet {
    return Intl.message(
      'Create Account',
      name: 'create_wallet',
      desc: '',
      args: [],
    );
  }

  /// `Delete Account`
  String get delete_wallet {
    return Intl.message(
      'Delete Account',
      name: 'delete_wallet',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to delete this account?`
  String get delete_wallet_confirm_title {
    return Intl.message(
      'Are you sure you want to delete this account?',
      name: 'delete_wallet_confirm_title',
      desc: '',
      args: [],
    );
  }

  /// `This will remove the account off your local device. Please make sure your account is fully backed up or you will lose your funds.`
  String get delete_wallet_confirm_text {
    return Intl.message(
      'This will remove the account off your local device. Please make sure your account is fully backed up or you will lose your funds.',
      name: 'delete_wallet_confirm_text',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to delete this message?`
  String get delete_message_confirm_title {
    return Intl.message(
      'Are you sure you want to delete this message?',
      name: 'delete_message_confirm_title',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to delete this contact?`
  String get delete_contact_confirm_title {
    return Intl.message(
      'Are you sure you want to delete this contact?',
      name: 'delete_contact_confirm_title',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to delete this friend?`
  String get delete_friend_confirm_title {
    return Intl.message(
      'Are you sure you want to delete this friend?',
      name: 'delete_friend_confirm_title',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to leave this group?`
  String get leave_group_confirm_title {
    return Intl.message(
      'Are you sure you want to leave this group?',
      name: 'leave_group_confirm_title',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to delete cache?`
  String get delete_cache_confirm_title {
    return Intl.message(
      'Are you sure you want to delete cache?',
      name: 'delete_cache_confirm_title',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to clear the database?`
  String get delete_db_confirm_title {
    return Intl.message(
      'Are you sure you want to clear the database?',
      name: 'delete_db_confirm_title',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to delete this device?`
  String get delete_device_confirm_title {
    return Intl.message(
      'Are you sure you want to delete this device?',
      name: 'delete_device_confirm_title',
      desc: '',
      args: [],
    );
  }

  /// `Keep your NKN organised`
  String get no_wallet_title {
    return Intl.message(
      'Keep your NKN organised',
      name: 'no_wallet_title',
      desc: '',
      args: [],
    );
  }

  /// `Manage both your Mainnet NKN\n tokens with our smart wallet manager.`
  String get no_wallet_desc {
    return Intl.message(
      'Manage both your Mainnet NKN\n tokens with our smart wallet manager.',
      name: 'no_wallet_desc',
      desc: '',
      args: [],
    );
  }

  /// `Create New Account`
  String get no_wallet_create {
    return Intl.message(
      'Create New Account',
      name: 'no_wallet_create',
      desc: '',
      args: [],
    );
  }

  /// `Import Existing Account`
  String get no_wallet_import {
    return Intl.message(
      'Import Existing Account',
      name: 'no_wallet_import',
      desc: '',
      args: [],
    );
  }

  /// `Create Mainnet Account`
  String get create_nkn_wallet {
    return Intl.message(
      'Create Mainnet Account',
      name: 'create_nkn_wallet',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN'),
      Locale.fromSubtags(languageCode: 'zh', countryCode: 'TW'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    if (locale != null) {
      for (var supportedLocale in supportedLocales) {
        if (supportedLocale.languageCode == locale.languageCode) {
          return true;
        }
      }
    }
    return false;
  }
}
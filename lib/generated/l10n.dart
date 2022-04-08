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
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(_current != null,
        'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.');
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(instance != null,
        'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?');
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
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

  /// `Done`
  String get done {
    return Intl.message(
      'Done',
      name: 'done',
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

  /// `Click this button for connect`
  String get click_connect {
    return Intl.message(
      'Click this button for connect',
      name: 'click_connect',
      desc: '',
      args: [],
    );
  }

  /// `Click to change`
  String get click_to_change {
    return Intl.message(
      'Click to change',
      name: 'click_to_change',
      desc: '',
      args: [],
    );
  }

  /// `Click to settings`
  String get click_to_settings {
    return Intl.message(
      'Click to settings',
      name: 'click_to_settings',
      desc: '',
      args: [],
    );
  }

  /// `You`
  String get you {
    return Intl.message(
      'You',
      name: 'you',
      desc: '',
      args: [],
    );
  }

  /// `Owner`
  String get owner {
    return Intl.message(
      'Owner',
      name: 'owner',
      desc: '',
      args: [],
    );
  }

  /// `seconds`
  String get seconds {
    return Intl.message(
      'seconds',
      name: 'seconds',
      desc: '',
      args: [],
    );
  }

  /// `minutes`
  String get minutes {
    return Intl.message(
      'minutes',
      name: 'minutes',
      desc: '',
      args: [],
    );
  }

  /// `hours`
  String get hours {
    return Intl.message(
      'hours',
      name: 'hours',
      desc: '',
      args: [],
    );
  }

  /// `days`
  String get days {
    return Intl.message(
      'days',
      name: 'days',
      desc: '',
      args: [],
    );
  }

  /// `weeks`
  String get weeks {
    return Intl.message(
      'weeks',
      name: 'weeks',
      desc: '',
      args: [],
    );
  }

  /// `Select`
  String get select {
    return Intl.message(
      'Select',
      name: 'select',
      desc: '',
      args: [],
    );
  }

  /// `Top`
  String get top {
    return Intl.message(
      'Top',
      name: 'top',
      desc: '',
      args: [],
    );
  }

  /// `Cancel Top`
  String get top_cancel {
    return Intl.message(
      'Cancel Top',
      name: 'top_cancel',
      desc: '',
      args: [],
    );
  }

  /// `authenticate to access`
  String get authenticate_to_access {
    return Intl.message(
      'authenticate to access',
      name: 'authenticate_to_access',
      desc: '',
      args: [],
    );
  }

  /// `Image`
  String get image {
    return Intl.message(
      'Image',
      name: 'image',
      desc: '',
      args: [],
    );
  }

  /// `Audio`
  String get audio {
    return Intl.message(
      'Audio',
      name: 'audio',
      desc: '',
      args: [],
    );
  }

  /// `Video`
  String get video {
    return Intl.message(
      'Video',
      name: 'video',
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

  /// `Biometrics`
  String get biometrics {
    return Intl.message(
      'Biometrics',
      name: 'biometrics',
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

  /// `MAINNET`
  String get mainnet {
    return Intl.message(
      'MAINNET',
      name: 'mainnet',
      desc: '',
      args: [],
    );
  }

  /// `NKN`
  String get nkn {
    return Intl.message(
      'NKN',
      name: 'nkn',
      desc: '',
      args: [],
    );
  }

  /// `ETH`
  String get eth {
    return Intl.message(
      'ETH',
      name: 'eth',
      desc: '',
      args: [],
    );
  }

  /// `Ethereum`
  String get ethereum {
    return Intl.message(
      'Ethereum',
      name: 'ethereum',
      desc: '',
      args: [],
    );
  }

  /// `ERC-20`
  String get ERC_20 {
    return Intl.message(
      'ERC-20',
      name: 'ERC_20',
      desc: '',
      args: [],
    );
  }

  /// `GWEI`
  String get gwei {
    return Intl.message(
      'GWEI',
      name: 'gwei',
      desc: '',
      args: [],
    );
  }

  /// `Gas Price`
  String get gas_price {
    return Intl.message(
      'Gas Price',
      name: 'gas_price',
      desc: '',
      args: [],
    );
  }

  /// `Max Gas`
  String get gas_max {
    return Intl.message(
      'Max Gas',
      name: 'gas_max',
      desc: '',
      args: [],
    );
  }

  /// `NKN Mainnet`
  String get nkn_mainnet {
    return Intl.message(
      'NKN Mainnet',
      name: 'nkn_mainnet',
      desc: '',
      args: [],
    );
  }

  /// `Create Ethereum Account`
  String get create_ethereum_wallet {
    return Intl.message(
      'Create Ethereum Account',
      name: 'create_ethereum_wallet',
      desc: '',
      args: [],
    );
  }

  /// `New Message`
  String get new_message {
    return Intl.message(
      'New Message',
      name: 'new_message',
      desc: '',
      args: [],
    );
  }

  /// `You have a new message`
  String get you_have_new_message {
    return Intl.message(
      'You have a new message',
      name: 'you_have_new_message',
      desc: '',
      args: [],
    );
  }

  /// `Private and Secure\n Messaging`
  String get chat_no_wallet_title {
    return Intl.message(
      'Private and Secure\n Messaging',
      name: 'chat_no_wallet_title',
      desc: '',
      args: [],
    );
  }

  /// `You need a Mainnet compatible wallet before you can use D-Chat.`
  String get chat_no_wallet_desc {
    return Intl.message(
      'You need a Mainnet compatible wallet before you can use D-Chat.',
      name: 'chat_no_wallet_desc',
      desc: '',
      args: [],
    );
  }

  /// `[Draft]`
  String get placeholder_draft {
    return Intl.message(
      '[Draft]',
      name: 'placeholder_draft',
      desc: '',
      args: [],
    );
  }

  /// `group invitation`
  String get channel_invitation {
    return Intl.message(
      'group invitation',
      name: 'channel_invitation',
      desc: '',
      args: [],
    );
  }

  /// `Accept Invitation`
  String get accept_invitation {
    return Intl.message(
      'Accept Invitation',
      name: 'accept_invitation',
      desc: '',
      args: [],
    );
  }

  /// `Joined group`
  String get joined_channel {
    return Intl.message(
      'Joined group',
      name: 'joined_channel',
      desc: '',
      args: [],
    );
  }

  /// `Start Chat`
  String get start_chat {
    return Intl.message(
      'Start Chat',
      name: 'start_chat',
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

  /// `Create Mainnet Account`
  String get create_nkn_wallet {
    return Intl.message(
      'Create Mainnet Account',
      name: 'create_nkn_wallet',
      desc: '',
      args: [],
    );
  }

  /// `Wallet Info missing, Quit and ReImport.`
  String get wallet_missing {
    return Intl.message(
      'Wallet Info missing, Quit and ReImport.',
      name: 'wallet_missing',
      desc: '',
      args: [],
    );
  }

  /// `My Accounts`
  String get my_wallets {
    return Intl.message(
      'My Accounts',
      name: 'my_wallets',
      desc: '',
      args: [],
    );
  }

  /// `Import Account`
  String get import_wallet {
    return Intl.message(
      'Import Account',
      name: 'import_wallet',
      desc: '',
      args: [],
    );
  }

  /// `Not backed up yet`
  String get not_backed_up {
    return Intl.message(
      'Not backed up yet',
      name: 'not_backed_up',
      desc: '',
      args: [],
    );
  }

  /// `Important: Please Back Up\n Your Accounts!`
  String get d_not_backed_up_title {
    return Intl.message(
      'Important: Please Back Up\n Your Accounts!',
      name: 'd_not_backed_up_title',
      desc: '',
      args: [],
    );
  }

  /// `When you update your nMobile software or accidentally uninstall nMobile, your wallet might be lost and you might NOT be able to access your assets! So please take 3 minutes time now to back up all your wallets.`
  String get d_not_backed_up_desc {
    return Intl.message(
      'When you update your nMobile software or accidentally uninstall nMobile, your wallet might be lost and you might NOT be able to access your assets! So please take 3 minutes time now to back up all your wallets.',
      name: 'd_not_backed_up_desc',
      desc: '',
      args: [],
    );
  }

  /// `Go Backup`
  String get go_backup {
    return Intl.message(
      'Go Backup',
      name: 'go_backup',
      desc: '',
      args: [],
    );
  }

  /// `Private Key`
  String get private_key {
    return Intl.message(
      'Private Key',
      name: 'private_key',
      desc: '',
      args: [],
    );
  }

  /// `Public Key`
  String get public_key {
    return Intl.message(
      'Public Key',
      name: 'public_key',
      desc: '',
      args: [],
    );
  }

  /// `View QR Code`
  String get view_qrcode {
    return Intl.message(
      'View QR Code',
      name: 'view_qrcode',
      desc: '',
      args: [],
    );
  }

  /// `QR Code`
  String get qrcode {
    return Intl.message(
      'QR Code',
      name: 'qrcode',
      desc: '',
      args: [],
    );
  }

  /// `Please save and backup your seed safely. Do not transfer via the internet. If you lose it you will lose access to your assets.`
  String get seed_qrcode_dec {
    return Intl.message(
      'Please save and backup your seed safely. Do not transfer via the internet. If you lose it you will lose access to your assets.',
      name: 'seed_qrcode_dec',
      desc: '',
      args: [],
    );
  }

  /// `Select Asset to Backup`
  String get select_asset_to_backup {
    return Intl.message(
      'Select Asset to Backup',
      name: 'select_asset_to_backup',
      desc: '',
      args: [],
    );
  }

  /// `Continue`
  String get continue_text {
    return Intl.message(
      'Continue',
      name: 'continue_text',
      desc: '',
      args: [],
    );
  }

  /// `Verify Account Password`
  String get verify_wallet_password {
    return Intl.message(
      'Verify Account Password',
      name: 'verify_wallet_password',
      desc: '',
      args: [],
    );
  }

  /// `Account password or keystore file is wrong.`
  String get password_wrong {
    return Intl.message(
      'Account password or keystore file is wrong.',
      name: 'password_wrong',
      desc: '',
      args: [],
    );
  }

  /// `Keystore`
  String get keystore {
    return Intl.message(
      'Keystore',
      name: 'keystore',
      desc: '',
      args: [],
    );
  }

  /// `Seed`
  String get seed {
    return Intl.message(
      'Seed',
      name: 'seed',
      desc: '',
      args: [],
    );
  }

  /// `Keystore`
  String get tab_keystore {
    return Intl.message(
      'Keystore',
      name: 'tab_keystore',
      desc: '',
      args: [],
    );
  }

  /// `Seed`
  String get tab_seed {
    return Intl.message(
      'Seed',
      name: 'tab_seed',
      desc: '',
      args: [],
    );
  }

  /// `Import Ethereum Account`
  String get import_ethereum_wallet {
    return Intl.message(
      'Import Ethereum Account',
      name: 'import_ethereum_wallet',
      desc: '',
      args: [],
    );
  }

  /// `Import Mainnet Account`
  String get import_nkn_wallet {
    return Intl.message(
      'Import Mainnet Account',
      name: 'import_nkn_wallet',
      desc: '',
      args: [],
    );
  }

  /// `Import with Keystore`
  String get import_with_keystore_title {
    return Intl.message(
      'Import with Keystore',
      name: 'import_with_keystore_title',
      desc: '',
      args: [],
    );
  }

  /// `From your existing wallet, find out how to export keystore as well as associated password, make a backup of both, and then use both to import your existing wallet into nMobile.`
  String get import_with_keystore_desc {
    return Intl.message(
      'From your existing wallet, find out how to export keystore as well as associated password, make a backup of both, and then use both to import your existing wallet into nMobile.',
      name: 'import_with_keystore_desc',
      desc: '',
      args: [],
    );
  }

  /// `Please paste keystore`
  String get input_keystore {
    return Intl.message(
      'Please paste keystore',
      name: 'input_keystore',
      desc: '',
      args: [],
    );
  }

  /// `Import with Seed`
  String get import_with_seed_title {
    return Intl.message(
      'Import with Seed',
      name: 'import_with_seed_title',
      desc: '',
      args: [],
    );
  }

  /// `From your existing wallet, find out how to export Seed (also called "Secret Seed"), make a backup copy, and then use it to import your existing wallet into nMobile.`
  String get import_with_seed_desc {
    return Intl.message(
      'From your existing wallet, find out how to export Seed (also called "Secret Seed"), make a backup copy, and then use it to import your existing wallet into nMobile.',
      name: 'import_with_seed_desc',
      desc: '',
      args: [],
    );
  }

  /// `Please input seed`
  String get input_seed {
    return Intl.message(
      'Please input seed',
      name: 'input_seed',
      desc: '',
      args: [],
    );
  }

  /// `This field is required.`
  String get error_required {
    return Intl.message(
      'This field is required.',
      name: 'error_required',
      desc: '',
      args: [],
    );
  }

  /// `{field} is required.`
  String error_field_required(Object field) {
    return Intl.message(
      '$field is required.',
      name: 'error_field_required',
      desc: '',
      args: [field],
    );
  }

  /// `Password does not match.`
  String get error_confirm_password {
    return Intl.message(
      'Password does not match.',
      name: 'error_confirm_password',
      desc: '',
      args: [],
    );
  }

  /// `Keystore format does not match.`
  String get error_keystore_format {
    return Intl.message(
      'Keystore format does not match.',
      name: 'error_keystore_format',
      desc: '',
      args: [],
    );
  }

  /// `Seed format does not match.`
  String get error_seed_format {
    return Intl.message(
      'Seed format does not match.',
      name: 'error_seed_format',
      desc: '',
      args: [],
    );
  }

  /// `Client address format does not match.`
  String get error_client_address_format {
    return Intl.message(
      'Client address format does not match.',
      name: 'error_client_address_format',
      desc: '',
      args: [],
    );
  }

  /// `Invalid wallet address.`
  String get error_nkn_address_format {
    return Intl.message(
      'Invalid wallet address.',
      name: 'error_nkn_address_format',
      desc: '',
      args: [],
    );
  }

  /// `Unknown NKN qr code.`
  String get error_unknown_nkn_qrcode {
    return Intl.message(
      'Unknown NKN qr code.',
      name: 'error_unknown_nkn_qrcode',
      desc: '',
      args: [],
    );
  }

  /// `To`
  String get to {
    return Intl.message(
      'To',
      name: 'to',
      desc: '',
      args: [],
    );
  }

  /// `Send To`
  String get send_to {
    return Intl.message(
      'Send To',
      name: 'send_to',
      desc: '',
      args: [],
    );
  }

  /// `From`
  String get from {
    return Intl.message(
      'From',
      name: 'from',
      desc: '',
      args: [],
    );
  }

  /// `Fee`
  String get fee {
    return Intl.message(
      'Fee',
      name: 'fee',
      desc: '',
      args: [],
    );
  }

  /// `Amount`
  String get amount {
    return Intl.message(
      'Amount',
      name: 'amount',
      desc: '',
      args: [],
    );
  }

  /// `Enter amount`
  String get enter_amount {
    return Intl.message(
      'Enter amount',
      name: 'enter_amount',
      desc: '',
      args: [],
    );
  }

  /// `Available`
  String get available {
    return Intl.message(
      'Available',
      name: 'available',
      desc: '',
      args: [],
    );
  }

  /// `Enter receive address`
  String get enter_receive_address {
    return Intl.message(
      'Enter receive address',
      name: 'enter_receive_address',
      desc: '',
      args: [],
    );
  }

  /// `Transfer Initiated`
  String get transfer_initiated {
    return Intl.message(
      'Transfer Initiated',
      name: 'transfer_initiated',
      desc: '',
      args: [],
    );
  }

  /// `Your transfer is in progress. It could take a few seconds to appear on the blockchain.`
  String get transfer_initiated_desc {
    return Intl.message(
      'Your transfer is in progress. It could take a few seconds to appear on the blockchain.',
      name: 'transfer_initiated_desc',
      desc: '',
      args: [],
    );
  }

  /// `Setting a reasonable NKN can speed up the transaction process.`
  String get transfer_speed_up_fee {
    return Intl.message(
      'Setting a reasonable NKN can speed up the transaction process.',
      name: 'transfer_speed_up_fee',
      desc: '',
      args: [],
    );
  }

  /// `Group chat renewal is turned on and auto-accelerate.`
  String get topic_renewal_speed_up_auto {
    return Intl.message(
      'Group chat renewal is turned on and auto-accelerate.',
      name: 'topic_renewal_speed_up_auto',
      desc: '',
      args: [],
    );
  }

  /// `Group chat renewal is turned on and does not auto-accelerate.`
  String get topic_renewal_speed_up_auto_no {
    return Intl.message(
      'Group chat renewal is turned on and does not auto-accelerate.',
      name: 'topic_renewal_speed_up_auto_no',
      desc: '',
      args: [],
    );
  }

  /// `The acceleration function requires additional NKN, please make sure you have enough NKN in your wallet.`
  String get transfer_speed_up_desc {
    return Intl.message(
      'The acceleration function requires additional NKN, please make sure you have enough NKN in your wallet.',
      name: 'transfer_speed_up_desc',
      desc: '',
      args: [],
    );
  }

  /// `Whether to enable acceleration`
  String get transfer_speed_up_enable {
    return Intl.message(
      'Whether to enable acceleration',
      name: 'transfer_speed_up_enable',
      desc: '',
      args: [],
    );
  }

  /// `Pay NKN amount`
  String get pay_nkn {
    return Intl.message(
      'Pay NKN amount',
      name: 'pay_nkn',
      desc: '',
      args: [],
    );
  }

  /// `accelerate`
  String get accelerate {
    return Intl.message(
      'accelerate',
      name: 'accelerate',
      desc: '',
      args: [],
    );
  }

  /// `no accelerate`
  String get accelerate_no {
    return Intl.message(
      'no accelerate',
      name: 'accelerate_no',
      desc: '',
      args: [],
    );
  }

  /// `Topic renewal`
  String get topic_resubscribe_enable {
    return Intl.message(
      'Topic renewal',
      name: 'topic_resubscribe_enable',
      desc: '',
      args: [],
    );
  }

  /// `Max`
  String get max {
    return Intl.message(
      'Max',
      name: 'max',
      desc: '',
      args: [],
    );
  }

  /// `Min`
  String get min {
    return Intl.message(
      'Min',
      name: 'min',
      desc: '',
      args: [],
    );
  }

  /// `Slow`
  String get slow {
    return Intl.message(
      'Slow',
      name: 'slow',
      desc: '',
      args: [],
    );
  }

  /// `Average`
  String get average {
    return Intl.message(
      'Average',
      name: 'average',
      desc: '',
      args: [],
    );
  }

  /// `Fast`
  String get fast {
    return Intl.message(
      'Fast',
      name: 'fast',
      desc: '',
      args: [],
    );
  }

  /// `Main Account`
  String get main_wallet {
    return Intl.message(
      'Main Account',
      name: 'main_wallet',
      desc: '',
      args: [],
    );
  }

  /// `Export Account`
  String get export_wallet {
    return Intl.message(
      'Export Account',
      name: 'export_wallet',
      desc: '',
      args: [],
    );
  }

  /// `Send`
  String get send {
    return Intl.message(
      'Send',
      name: 'send',
      desc: '',
      args: [],
    );
  }

  /// `Send NKN`
  String get send_nkn {
    return Intl.message(
      'Send NKN',
      name: 'send_nkn',
      desc: '',
      args: [],
    );
  }

  /// `Send Eth`
  String get send_eth {
    return Intl.message(
      'Send Eth',
      name: 'send_eth',
      desc: '',
      args: [],
    );
  }

  /// `Receive`
  String get receive {
    return Intl.message(
      'Receive',
      name: 'receive',
      desc: '',
      args: [],
    );
  }

  /// `Account Address`
  String get wallet_address {
    return Intl.message(
      'Account Address',
      name: 'wallet_address',
      desc: '',
      args: [],
    );
  }

  /// `Copy`
  String get copy {
    return Intl.message(
      'Copy',
      name: 'copy',
      desc: '',
      args: [],
    );
  }

  /// `Copied to Clipboard`
  String get copy_success {
    return Intl.message(
      'Copied to Clipboard',
      name: 'copy_success',
      desc: '',
      args: [],
    );
  }

  /// `Success`
  String get success {
    return Intl.message(
      'Success',
      name: 'success',
      desc: '',
      args: [],
    );
  }

  /// `Failure`
  String get failure {
    return Intl.message(
      'Failure',
      name: 'failure',
      desc: '',
      args: [],
    );
  }

  /// `Copied`
  String get copied {
    return Intl.message(
      'Copied',
      name: 'copied',
      desc: '',
      args: [],
    );
  }

  /// `Copy to Clipboard`
  String get copy_to_clipboard {
    return Intl.message(
      'Copy to Clipboard',
      name: 'copy_to_clipboard',
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

  /// `Are you sure you want to delete this conversation?`
  String get delete_session_confirm_title {
    return Intl.message(
      'Are you sure you want to delete this conversation?',
      name: 'delete_session_confirm_title',
      desc: '',
      args: [],
    );
  }

  /// `Select Asset to Send`
  String get select_asset_to_send {
    return Intl.message(
      'Select Asset to Send',
      name: 'select_asset_to_send',
      desc: '',
      args: [],
    );
  }

  /// `Select Asset to Receive`
  String get select_asset_to_receive {
    return Intl.message(
      'Select Asset to Receive',
      name: 'select_asset_to_receive',
      desc: '',
      args: [],
    );
  }

  /// `Select Another Account`
  String get select_another_wallet {
    return Intl.message(
      'Select Another Account',
      name: 'select_another_wallet',
      desc: '',
      args: [],
    );
  }

  /// `Select Account Type`
  String get select_wallet_type {
    return Intl.message(
      'Select Account Type',
      name: 'select_wallet_type',
      desc: '',
      args: [],
    );
  }

  /// `Select whether to create/import a NKN Mainnet wallet or an Ethereum based wallet to hold ERC-20 tokens. The two are not compatible.`
  String get select_wallet_type_desc {
    return Intl.message(
      'Select whether to create/import a NKN Mainnet wallet or an Ethereum based wallet to hold ERC-20 tokens. The two are not compatible.',
      name: 'select_wallet_type_desc',
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

  /// `Contacts`
  String get contacts {
    return Intl.message(
      'Contacts',
      name: 'contacts',
      desc: '',
      args: [],
    );
  }

  /// `Stranger`
  String get stranger {
    return Intl.message(
      'Stranger',
      name: 'stranger',
      desc: '',
      args: [],
    );
  }

  /// `My Contact`
  String get my_contact {
    return Intl.message(
      'My Contact',
      name: 'my_contact',
      desc: '',
      args: [],
    );
  }

  /// `Add Contact`
  String get add_contact {
    return Intl.message(
      'Add Contact',
      name: 'add_contact',
      desc: '',
      args: [],
    );
  }

  /// `Edit Contact`
  String get edit_contact {
    return Intl.message(
      'Edit Contact',
      name: 'edit_contact',
      desc: '',
      args: [],
    );
  }

  /// `Delete Contact`
  String get delete_contact {
    return Intl.message(
      'Delete Contact',
      name: 'delete_contact',
      desc: '',
      args: [],
    );
  }

  /// `Delete Conversation`
  String get delete_session {
    return Intl.message(
      'Delete Conversation',
      name: 'delete_session',
      desc: '',
      args: [],
    );
  }

  /// `You haven’t got any\n contacts yet`
  String get contact_no_contact_title {
    return Intl.message(
      'You haven’t got any\n contacts yet',
      name: 'contact_no_contact_title',
      desc: '',
      args: [],
    );
  }

  /// `Use your contact list to quickly message and\n send funds to your friends.`
  String get contact_no_contact_desc {
    return Intl.message(
      'Use your contact list to quickly message and\n send funds to your friends.',
      name: 'contact_no_contact_desc',
      desc: '',
      args: [],
    );
  }

  /// `Type a message`
  String get type_a_message {
    return Intl.message(
      'Type a message',
      name: 'type_a_message',
      desc: '',
      args: [],
    );
  }

  /// `Pictures`
  String get pictures {
    return Intl.message(
      'Pictures',
      name: 'pictures',
      desc: '',
      args: [],
    );
  }

  /// `Camera`
  String get camera {
    return Intl.message(
      'Camera',
      name: 'camera',
      desc: '',
      args: [],
    );
  }

  /// `Files`
  String get files {
    return Intl.message(
      'Files',
      name: 'files',
      desc: '',
      args: [],
    );
  }

  /// `Location`
  String get location {
    return Intl.message(
      'Location',
      name: 'location',
      desc: '',
      args: [],
    );
  }

  /// `Featured`
  String get featured {
    return Intl.message(
      'Featured',
      name: 'featured',
      desc: '',
      args: [],
    );
  }

  /// `Latest`
  String get latest {
    return Intl.message(
      'Latest',
      name: 'latest',
      desc: '',
      args: [],
    );
  }

  /// `Off`
  String get off {
    return Intl.message(
      'Off',
      name: 'off',
      desc: '',
      args: [],
    );
  }

  /// `Yes`
  String get yes {
    return Intl.message(
      'Yes',
      name: 'yes',
      desc: '',
      args: [],
    );
  }

  /// `No`
  String get no {
    return Intl.message(
      'No',
      name: 'no',
      desc: '',
      args: [],
    );
  }

  /// `Save To Album`
  String get save_to_album {
    return Intl.message(
      'Save To Album',
      name: 'save_to_album',
      desc: '',
      args: [],
    );
  }

  /// `Invitation sent`
  String get invitation_sent {
    return Intl.message(
      'Invitation sent',
      name: 'invitation_sent',
      desc: '',
      args: [],
    );
  }

  /// `Rename`
  String get rename {
    return Intl.message(
      'Rename',
      name: 'rename',
      desc: '',
      args: [],
    );
  }

  /// `Edit`
  String get edit {
    return Intl.message(
      'Edit',
      name: 'edit',
      desc: '',
      args: [],
    );
  }

  /// `Edit Name`
  String get edit_name {
    return Intl.message(
      'Edit Name',
      name: 'edit_name',
      desc: '',
      args: [],
    );
  }

  /// `Edit Nickname`
  String get edit_nickname {
    return Intl.message(
      'Edit Nickname',
      name: 'edit_nickname',
      desc: '',
      args: [],
    );
  }

  /// `Please input Nickname`
  String get input_nickname {
    return Intl.message(
      'Please input Nickname',
      name: 'input_nickname',
      desc: '',
      args: [],
    );
  }

  /// `Please input Public Key`
  String get input_pubKey {
    return Intl.message(
      'Please input Public Key',
      name: 'input_pubKey',
      desc: '',
      args: [],
    );
  }

  /// `Please input Name`
  String get input_name {
    return Intl.message(
      'Please input Name',
      name: 'input_name',
      desc: '',
      args: [],
    );
  }

  /// `Please input Account Address`
  String get input_wallet_address {
    return Intl.message(
      'Please input Account Address',
      name: 'input_wallet_address',
      desc: '',
      args: [],
    );
  }

  /// `Please input Notes`
  String get input_notes {
    return Intl.message(
      'Please input Notes',
      name: 'input_notes',
      desc: '',
      args: [],
    );
  }

  /// `Edit Notes`
  String get edit_notes {
    return Intl.message(
      'Edit Notes',
      name: 'edit_notes',
      desc: '',
      args: [],
    );
  }

  /// `View All`
  String get view_all {
    return Intl.message(
      'View All',
      name: 'view_all',
      desc: '',
      args: [],
    );
  }

  /// `Latest Transactions`
  String get latest_transactions {
    return Intl.message(
      'Latest Transactions',
      name: 'latest_transactions',
      desc: '',
      args: [],
    );
  }

  /// `Today`
  String get today {
    return Intl.message(
      'Today',
      name: 'today',
      desc: '',
      args: [],
    );
  }

  /// `Notes`
  String get notes {
    return Intl.message(
      'Notes',
      name: 'notes',
      desc: '',
      args: [],
    );
  }

  /// `None`
  String get none {
    return Intl.message(
      'None',
      name: 'none',
      desc: '',
      args: [],
    );
  }

  /// `nMobile`
  String get title {
    return Intl.message(
      'nMobile',
      name: 'title',
      desc: '',
      args: [],
    );
  }

  /// `My Details`
  String get my_details {
    return Intl.message(
      'My Details',
      name: 'my_details',
      desc: '',
      args: [],
    );
  }

  /// `Your password must be at least 8 characters. It is recommended to use a mix of different characters.`
  String get wallet_password_helper_text {
    return Intl.message(
      'Your password must be at least 8 characters. It is recommended to use a mix of different characters.',
      name: 'wallet_password_helper_text',
      desc: '',
      args: [],
    );
  }

  /// `Your password must be at least 8 characters. It is recommended to use a mix of different characters.`
  String get wallet_password_error {
    return Intl.message(
      'Your password must be at least 8 characters. It is recommended to use a mix of different characters.',
      name: 'wallet_password_error',
      desc: '',
      args: [],
    );
  }

  /// `Create`
  String get create {
    return Intl.message(
      'Create',
      name: 'create',
      desc: '',
      args: [],
    );
  }

  /// `Save Contact`
  String get save_contact {
    return Intl.message(
      'Save Contact',
      name: 'save_contact',
      desc: '',
      args: [],
    );
  }

  /// `Members`
  String get view_channel_members {
    return Intl.message(
      'Members',
      name: 'view_channel_members',
      desc: '',
      args: [],
    );
  }

  /// `Invite Members`
  String get invite_members {
    return Intl.message(
      'Invite Members',
      name: 'invite_members',
      desc: '',
      args: [],
    );
  }

  /// `TOTAL BALANCE`
  String get total_balance {
    return Intl.message(
      'TOTAL BALANCE',
      name: 'total_balance',
      desc: '',
      args: [],
    );
  }

  /// `Eth Account`
  String get eth_wallet {
    return Intl.message(
      'Eth Account',
      name: 'eth_wallet',
      desc: '',
      args: [],
    );
  }

  /// `Enter first name`
  String get enter_first_name {
    return Intl.message(
      'Enter first name',
      name: 'enter_first_name',
      desc: '',
      args: [],
    );
  }

  /// `Enter last name`
  String get enter_last_name {
    return Intl.message(
      'Enter last name',
      name: 'enter_last_name',
      desc: '',
      args: [],
    );
  }

  /// `Enter users address`
  String get enter_users_address {
    return Intl.message(
      'Enter users address',
      name: 'enter_users_address',
      desc: '',
      args: [],
    );
  }

  /// `Enter topic`
  String get enter_topic {
    return Intl.message(
      'Enter topic',
      name: 'enter_topic',
      desc: '',
      args: [],
    );
  }

  /// `Direct Message`
  String get new_whisper {
    return Intl.message(
      'Direct Message',
      name: 'new_whisper',
      desc: '',
      args: [],
    );
  }

  /// `New Group`
  String get new_group {
    return Intl.message(
      'New Group',
      name: 'new_group',
      desc: '',
      args: [],
    );
  }

  /// `Create/Join to group`
  String get create_channel {
    return Intl.message(
      'Create/Join to group',
      name: 'create_channel',
      desc: '',
      args: [],
    );
  }

  /// `Private Group`
  String get private_channel {
    return Intl.message(
      'Private Group',
      name: 'private_channel',
      desc: '',
      args: [],
    );
  }

  /// `Private`
  String get private {
    return Intl.message(
      'Private',
      name: 'private',
      desc: '',
      args: [],
    );
  }

  /// `Group Settings`
  String get channel_settings {
    return Intl.message(
      'Group Settings',
      name: 'channel_settings',
      desc: '',
      args: [],
    );
  }

  /// `Group Members`
  String get channel_members {
    return Intl.message(
      'Group Members',
      name: 'channel_members',
      desc: '',
      args: [],
    );
  }

  /// `Topic`
  String get topic {
    return Intl.message(
      'Topic',
      name: 'topic',
      desc: '',
      args: [],
    );
  }

  /// `Address Book`
  String get address_book {
    return Intl.message(
      'Address Book',
      name: 'address_book',
      desc: '',
      args: [],
    );
  }

  /// `Popular Groups`
  String get popular_channels {
    return Intl.message(
      'Popular Groups',
      name: 'popular_channels',
      desc: '',
      args: [],
    );
  }

  /// `My Group`
  String get my_group {
    return Intl.message(
      'My Group',
      name: 'my_group',
      desc: '',
      args: [],
    );
  }

  /// `D-Chat Settings`
  String get chat_settings {
    return Intl.message(
      'D-Chat Settings',
      name: 'chat_settings',
      desc: '',
      args: [],
    );
  }

  /// `View Profile`
  String get view_profile {
    return Intl.message(
      'View Profile',
      name: 'view_profile',
      desc: '',
      args: [],
    );
  }

  /// `Remark`
  String get remark {
    return Intl.message(
      'Remark',
      name: 'remark',
      desc: '',
      args: [],
    );
  }

  /// `Contact`
  String get contact {
    return Intl.message(
      'Contact',
      name: 'contact',
      desc: '',
      args: [],
    );
  }

  /// `Recently`
  String get recent {
    return Intl.message(
      'Recently',
      name: 'recent',
      desc: '',
      args: [],
    );
  }

  /// `Burn After Reading`
  String get burn_after_reading {
    return Intl.message(
      'Burn After Reading',
      name: 'burn_after_reading',
      desc: '',
      args: [],
    );
  }

  /// `When turned on, you will receive immediate notification when this person sends you messages.`
  String get accept_notification {
    return Intl.message(
      'When turned on, you will receive immediate notification when this person sends you messages.',
      name: 'accept_notification',
      desc: '',
      args: [],
    );
  }

  /// `Have Denied Remote Notification`
  String get setting_deny_notification {
    return Intl.message(
      'Have Denied Remote Notification',
      name: 'setting_deny_notification',
      desc: '',
      args: [],
    );
  }

  /// `Have Accepted Remote Notification`
  String get setting_accept_notification {
    return Intl.message(
      'Have Accepted Remote Notification',
      name: 'setting_accept_notification',
      desc: '',
      args: [],
    );
  }

  /// `New Message!`
  String get notification_push_content {
    return Intl.message(
      'New Message!',
      name: 'notification_push_content',
      desc: '',
      args: [],
    );
  }

  /// `Message Notification`
  String get remote_notification {
    return Intl.message(
      'Message Notification',
      name: 'remote_notification',
      desc: '',
      args: [],
    );
  }

  /// `Search`
  String get search {
    return Intl.message(
      'Search',
      name: 'search',
      desc: '',
      args: [],
    );
  }

  /// `App Version`
  String get app_version {
    return Intl.message(
      'App Version',
      name: 'app_version',
      desc: '',
      args: [],
    );
  }

  /// `Auto`
  String get auto {
    return Intl.message(
      'Auto',
      name: 'auto',
      desc: '',
      args: [],
    );
  }

  /// `Me`
  String get me {
    return Intl.message(
      'Me',
      name: 'me',
      desc: '',
      args: [],
    );
  }

  /// `Client Address`
  String get client_address {
    return Intl.message(
      'Client Address',
      name: 'client_address',
      desc: '',
      args: [],
    );
  }

  /// `First Name`
  String get first_name {
    return Intl.message(
      'First Name',
      name: 'first_name',
      desc: '',
      args: [],
    );
  }

  /// `Last Name`
  String get last_name {
    return Intl.message(
      'Last Name',
      name: 'last_name',
      desc: '',
      args: [],
    );
  }

  /// `Updated at`
  String get updated_at {
    return Intl.message(
      'Updated at',
      name: 'updated_at',
      desc: '',
      args: [],
    );
  }

  /// `Settings`
  String get settings {
    return Intl.message(
      'Settings',
      name: 'settings',
      desc: '',
      args: [],
    );
  }

  /// `members`
  String get members {
    return Intl.message(
      'members',
      name: 'members',
      desc: '',
      args: [],
    );
  }

  /// `{other} invites You to join group`
  String invites_desc_me(Object other) {
    return Intl.message(
      '$other invites You to join group',
      name: 'invites_desc_me',
      desc: '',
      args: [other],
    );
  }

  /// `You invites {other} to join group`
  String invites_desc_other(Object other) {
    return Intl.message(
      'You invites $other to join group',
      name: 'invites_desc_other',
      desc: '',
      args: [other],
    );
  }

  /// `Accept`
  String get accept {
    return Intl.message(
      'Accept',
      name: 'accept',
      desc: '',
      args: [],
    );
  }

  /// `accepted`
  String get accepted {
    return Intl.message(
      'accepted',
      name: 'accepted',
      desc: '',
      args: [],
    );
  }

  /// `You have already accepted`
  String get accepted_already {
    return Intl.message(
      'You have already accepted',
      name: 'accepted_already',
      desc: '',
      args: [],
    );
  }

  /// `rejected`
  String get rejected {
    return Intl.message(
      'rejected',
      name: 'rejected',
      desc: '',
      args: [],
    );
  }

  /// `pending`
  String get pending {
    return Intl.message(
      'pending',
      name: 'pending',
      desc: '',
      args: [],
    );
  }

  /// `Debug`
  String get debug {
    return Intl.message(
      'Debug',
      name: 'debug',
      desc: '',
      args: [],
    );
  }

  /// `Subscribe`
  String get subscribe {
    return Intl.message(
      'Subscribe',
      name: 'subscribe',
      desc: '',
      args: [],
    );
  }

  /// `Subscribe or Waiting...`
  String get subscribe_or_waiting {
    return Intl.message(
      'Subscribe or Waiting...',
      name: 'subscribe_or_waiting',
      desc: '',
      args: [],
    );
  }

  /// `Subscribed`
  String get subscribed {
    return Intl.message(
      'Subscribed',
      name: 'subscribed',
      desc: '',
      args: [],
    );
  }

  /// `Leave`
  String get unsubscribe {
    return Intl.message(
      'Leave',
      name: 'unsubscribe',
      desc: '',
      args: [],
    );
  }

  /// `Leaved`
  String get unsubscribed {
    return Intl.message(
      'Leaved',
      name: 'unsubscribed',
      desc: '',
      args: [],
    );
  }

  /// `by`
  String get news_from {
    return Intl.message(
      'by',
      name: 'news_from',
      desc: '',
      args: [],
    );
  }

  /// `Messages`
  String get chat_tab_messages {
    return Intl.message(
      'Messages',
      name: 'chat_tab_messages',
      desc: '',
      args: [],
    );
  }

  /// `Groups`
  String get chat_tab_channels {
    return Intl.message(
      'Groups',
      name: 'chat_tab_channels',
      desc: '',
      args: [],
    );
  }

  /// `Group`
  String get chat_tab_group {
    return Intl.message(
      'Group',
      name: 'chat_tab_group',
      desc: '',
      args: [],
    );
  }

  /// `Private and Secure\nMessaging`
  String get chat_no_messages_title {
    return Intl.message(
      'Private and Secure\nMessaging',
      name: 'chat_no_messages_title',
      desc: '',
      args: [],
    );
  }

  /// `Start a new direct message or group chat, or join\nexisting ones..`
  String get chat_no_messages_desc {
    return Intl.message(
      'Start a new direct message or group chat, or join\nexisting ones..',
      name: 'chat_no_messages_desc',
      desc: '',
      args: [],
    );
  }

  /// `set the disappearing message timer`
  String get update_burn_after_reading {
    return Intl.message(
      'set the disappearing message timer',
      name: 'update_burn_after_reading',
      desc: '',
      args: [],
    );
  }

  /// `disabled disappearing messages`
  String get close_burn_after_reading {
    return Intl.message(
      'disabled disappearing messages',
      name: 'close_burn_after_reading',
      desc: '',
      args: [],
    );
  }

  /// `5 seconds`
  String get burn_5_seconds {
    return Intl.message(
      '5 seconds',
      name: 'burn_5_seconds',
      desc: '',
      args: [],
    );
  }

  /// `10 seconds`
  String get burn_10_seconds {
    return Intl.message(
      '10 seconds',
      name: 'burn_10_seconds',
      desc: '',
      args: [],
    );
  }

  /// `30 seconds`
  String get burn_30_seconds {
    return Intl.message(
      '30 seconds',
      name: 'burn_30_seconds',
      desc: '',
      args: [],
    );
  }

  /// `1 minute`
  String get burn_1_minute {
    return Intl.message(
      '1 minute',
      name: 'burn_1_minute',
      desc: '',
      args: [],
    );
  }

  /// `5 minutes`
  String get burn_5_minutes {
    return Intl.message(
      '5 minutes',
      name: 'burn_5_minutes',
      desc: '',
      args: [],
    );
  }

  /// `10 minutes`
  String get burn_10_minutes {
    return Intl.message(
      '10 minutes',
      name: 'burn_10_minutes',
      desc: '',
      args: [],
    );
  }

  /// `30 minutes`
  String get burn_30_minutes {
    return Intl.message(
      '30 minutes',
      name: 'burn_30_minutes',
      desc: '',
      args: [],
    );
  }

  /// `1 hour`
  String get burn_1_hour {
    return Intl.message(
      '1 hour',
      name: 'burn_1_hour',
      desc: '',
      args: [],
    );
  }

  /// `6 hours`
  String get burn_6_hour {
    return Intl.message(
      '6 hours',
      name: 'burn_6_hour',
      desc: '',
      args: [],
    );
  }

  /// `12 hours`
  String get burn_12_hour {
    return Intl.message(
      '12 hours',
      name: 'burn_12_hour',
      desc: '',
      args: [],
    );
  }

  /// `1 day`
  String get burn_1_day {
    return Intl.message(
      '1 day',
      name: 'burn_1_day',
      desc: '',
      args: [],
    );
  }

  /// `1 week`
  String get burn_1_week {
    return Intl.message(
      '1 week',
      name: 'burn_1_week',
      desc: '',
      args: [],
    );
  }

  /// `Add New Contact`
  String get add_new_contact {
    return Intl.message(
      'Add New Contact',
      name: 'add_new_contact',
      desc: '',
      args: [],
    );
  }

  /// `optional`
  String get optional {
    return Intl.message(
      'optional',
      name: 'optional',
      desc: '',
      args: [],
    );
  }

  /// `Private Messages`
  String get private_messages {
    return Intl.message(
      'Private Messages',
      name: 'private_messages',
      desc: '',
      args: [],
    );
  }

  /// `All direct messages are completely private and secure.`
  String get private_messages_desc {
    return Intl.message(
      'All direct messages are completely private and secure.',
      name: 'private_messages_desc',
      desc: '',
      args: [],
    );
  }

  /// `Learn More`
  String get learn_more {
    return Intl.message(
      'Learn More',
      name: 'learn_more',
      desc: '',
      args: [],
    );
  }

  /// `Enter/Select a user D-Chat ID`
  String get enter_or_select_a_user_pubkey {
    return Intl.message(
      'Enter/Select a user D-Chat ID',
      name: 'enter_or_select_a_user_pubkey',
      desc: '',
      args: [],
    );
  }

  /// `Scan the QR code pattern to add friends to your contacts.`
  String get scan_show_me_desc {
    return Intl.message(
      'Scan the QR code pattern to add friends to your contacts.',
      name: 'scan_show_me_desc',
      desc: '',
      args: [],
    );
  }

  /// `Nickname`
  String get nickname {
    return Intl.message(
      'Nickname',
      name: 'nickname',
      desc: '',
      args: [],
    );
  }

  /// `D-Chat ID`
  String get d_chat_address {
    return Intl.message(
      'D-Chat ID',
      name: 'd_chat_address',
      desc: '',
      args: [],
    );
  }

  /// `Please input D-Chat ID`
  String get input_d_chat_address {
    return Intl.message(
      'Please input D-Chat ID',
      name: 'input_d_chat_address',
      desc: '',
      args: [],
    );
  }

  /// `Wrong password`
  String get tip_password_error {
    return Intl.message(
      'Wrong password',
      name: 'tip_password_error',
      desc: '',
      args: [],
    );
  }

  /// `Friend`
  String get friends {
    return Intl.message(
      'Friend',
      name: 'friends',
      desc: '',
      args: [],
    );
  }

  /// `Group`
  String get group_chat {
    return Intl.message(
      'Group',
      name: 'group_chat',
      desc: '',
      args: [],
    );
  }

  /// `D-Chat not login`
  String get d_chat_not_login {
    return Intl.message(
      'D-Chat not login',
      name: 'd_chat_not_login',
      desc: '',
      args: [],
    );
  }

  /// `Create Account`
  String get create_account {
    return Intl.message(
      'Create Account',
      name: 'create_account',
      desc: '',
      args: [],
    );
  }

  /// `Import Account`
  String get import_wallet_as_account {
    return Intl.message(
      'Import Account',
      name: 'import_wallet_as_account',
      desc: '',
      args: [],
    );
  }

  /// `Tips`
  String get tip {
    return Intl.message(
      'Tips',
      name: 'tip',
      desc: '',
      args: [],
    );
  }

  /// `Change`
  String get change_default_chat_wallet {
    return Intl.message(
      'Change',
      name: 'change_default_chat_wallet',
      desc: '',
      args: [],
    );
  }

  /// `Coming Soon...`
  String get coming_soon {
    return Intl.message(
      'Coming Soon...',
      name: 'coming_soon',
      desc: '',
      args: [],
    );
  }

  /// `My Profile`
  String get my_profile {
    return Intl.message(
      'My Profile',
      name: 'my_profile',
      desc: '',
      args: [],
    );
  }

  /// `Profile`
  String get profile {
    return Intl.message(
      'Profile',
      name: 'profile',
      desc: '',
      args: [],
    );
  }

  /// `Send Message`
  String get send_message {
    return Intl.message(
      'Send Message',
      name: 'send_message',
      desc: '',
      args: [],
    );
  }

  /// `Scan the QR code, you can transfer it to me`
  String get show_wallet_address_desc {
    return Intl.message(
      'Scan the QR code, you can transfer it to me',
      name: 'show_wallet_address_desc',
      desc: '',
      args: [],
    );
  }

  /// `Account switching Completed`
  String get account_switching_completed {
    return Intl.message(
      'Account switching Completed',
      name: 'account_switching_completed',
      desc: '',
      args: [],
    );
  }

  /// `Storage`
  String get storage_text {
    return Intl.message(
      'Storage',
      name: 'storage_text',
      desc: '',
      args: [],
    );
  }

  /// `Export`
  String get export {
    return Intl.message(
      'Export',
      name: 'export',
      desc: '',
      args: [],
    );
  }

  /// `The current version does not support ERC20 Token transactions. Please export this wallet keystore for backup immediately.`
  String get eth_keystore_export_desc {
    return Intl.message(
      'The current version does not support ERC20 Token transactions. Please export this wallet keystore for backup immediately.',
      name: 'eth_keystore_export_desc',
      desc: '',
      args: [],
    );
  }

  /// `Messages sent and received in this conversation will disappear {time} after they have been seen.`
  String burn_after_reading_desc_disappear(Object time) {
    return Intl.message(
      'Messages sent and received in this conversation will disappear $time after they have been seen.',
      name: 'burn_after_reading_desc_disappear',
      desc: '',
      args: [time],
    );
  }

  /// `Your messages will not expire.`
  String get burn_after_reading_desc {
    return Intl.message(
      'Your messages will not expire.',
      name: 'burn_after_reading_desc',
      desc: '',
      args: [],
    );
  }

  /// `Oops, something went wrong! Please try again later.`
  String get something_went_wrong {
    return Intl.message(
      'Oops, something went wrong! Please try again later.',
      name: 'something_went_wrong',
      desc: '',
      args: [],
    );
  }

  /// `Not available for Android device without Google Service Currently`
  String get unavailable_device {
    return Intl.message(
      'Not available for Android device without Google Service Currently',
      name: 'unavailable_device',
      desc: '',
      args: [],
    );
  }

  /// `< Slide Cancel <`
  String get slide_to_cancel {
    return Intl.message(
      '< Slide Cancel <',
      name: 'slide_to_cancel',
      desc: '',
      args: [],
    );
  }

  /// `invite and send success`
  String get invite_and_send_success {
    return Intl.message(
      'invite and send success',
      name: 'invite_and_send_success',
      desc: '',
      args: [],
    );
  }

  /// `not invited`
  String get join_but_not_invite {
    return Intl.message(
      'not invited',
      name: 'join_but_not_invite',
      desc: '',
      args: [],
    );
  }

  /// `inviting`
  String get inviting {
    return Intl.message(
      'inviting',
      name: 'inviting',
      desc: '',
      args: [],
    );
  }

  /// `subscribing`
  String get subscribing {
    return Intl.message(
      'subscribing',
      name: 'subscribing',
      desc: '',
      args: [],
    );
  }

  /// `Need to re-subscribe`
  String get need_re_subscribe {
    return Intl.message(
      'Need to re-subscribe',
      name: 'need_re_subscribe',
      desc: '',
      args: [],
    );
  }

  /// `You have already invited this member,still invite?`
  String get invited_already {
    return Intl.message(
      'You have already invited this member,still invite?',
      name: 'invited_already',
      desc: '',
      args: [],
    );
  }

  /// `The member is in group already`
  String get group_member_already {
    return Intl.message(
      'The member is in group already',
      name: 'group_member_already',
      desc: '',
      args: [],
    );
  }

  /// `Can not invite yourself!`
  String get invite_yourself_error {
    return Intl.message(
      'Can not invite yourself!',
      name: 'invite_yourself_error',
      desc: '',
      args: [],
    );
  }

  /// `Private group member can not invite others currently,ask group owner to invite others`
  String get member_no_auth_invite {
    return Intl.message(
      'Private group member can not invite others currently,ask group owner to invite others',
      name: 'member_no_auth_invite',
      desc: '',
      args: [],
    );
  }

  /// `Whether to open the notification reminder from the other party?`
  String get tip_open_send_device_token {
    return Intl.message(
      'Whether to open the notification reminder from the other party?',
      name: 'tip_open_send_device_token',
      desc: '',
      args: [],
    );
  }

  /// `Switch Success!`
  String get tip_switch_success {
    return Intl.message(
      'Switch Success!',
      name: 'tip_switch_success',
      desc: '',
      args: [],
    );
  }

  /// `You are not in this group,ask the group owner for permission`
  String get tip_ask_group_owner_permission {
    return Intl.message(
      'You are not in this group,ask the group owner for permission',
      name: 'tip_ask_group_owner_permission',
      desc: '',
      args: [],
    );
  }

  /// `Left the group, please try again later.`
  String get left_group_tip {
    return Intl.message(
      'Left the group, please try again later.',
      name: 'left_group_tip',
      desc: '',
      args: [],
    );
  }

  /// `You have been removed from the group, please contact the owner to invite you`
  String get removed_group_tip {
    return Intl.message(
      'You have been removed from the group, please contact the owner to invite you',
      name: 'removed_group_tip',
      desc: '',
      args: [],
    );
  }

  /// `Please contact the owner to invite you`
  String get contact_invite_group_tip {
    return Intl.message(
      'Please contact the owner to invite you',
      name: 'contact_invite_group_tip',
      desc: '',
      args: [],
    );
  }

  /// `Requests still being processed, please try again later`
  String get request_processed {
    return Intl.message(
      'Requests still being processed, please try again later',
      name: 'request_processed',
      desc: '',
      args: [],
    );
  }

  /// `The user has been blocked, and ordinary members are not allowed to invite`
  String get blocked_user_disallow_invite {
    return Intl.message(
      'The user has been blocked, and ordinary members are not allowed to invite',
      name: 'blocked_user_disallow_invite',
      desc: '',
      args: [],
    );
  }

  /// `Confirm resend?`
  String get confirm_resend {
    return Intl.message(
      'Confirm resend?',
      name: 'confirm_resend',
      desc: '',
      args: [],
    );
  }

  /// `Release to cancel`
  String get release_to_cancel {
    return Intl.message(
      'Release to cancel',
      name: 'release_to_cancel',
      desc: '',
      args: [],
    );
  }

  /// `Left group`
  String get has_left_the_group {
    return Intl.message(
      'Left group',
      name: 'has_left_the_group',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to remove this user?`
  String get reject_user_tip {
    return Intl.message(
      'Are you sure you want to remove this user?',
      name: 'reject_user_tip',
      desc: '',
      args: [],
    );
  }

  /// `The file is too big`
  String get file_too_big {
    return Intl.message(
      'The file is too big',
      name: 'file_too_big',
      desc: '',
      args: [],
    );
  }

  /// `The file does not exist`
  String get file_not_exist {
    return Intl.message(
      'The file does not exist',
      name: 'file_not_exist',
      desc: '',
      args: [],
    );
  }

  /// `The user has been added`
  String get add_user_duplicated {
    return Intl.message(
      'The user has been added',
      name: 'add_user_duplicated',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to leave the group chat?`
  String get confirm_unsubscribe_group {
    return Intl.message(
      'Are you sure you want to leave the group chat?',
      name: 'confirm_unsubscribe_group',
      desc: '',
      args: [],
    );
  }

  /// `Balance not enough`
  String get balance_not_enough {
    return Intl.message(
      'Balance not enough',
      name: 'balance_not_enough',
      desc: '',
      args: [],
    );
  }

  /// `Have not been granted permission to join the group, please try again later.`
  String get no_permission_join_group {
    return Intl.message(
      'Have not been granted permission to join the group, please try again later.',
      name: 'no_permission_join_group',
      desc: '',
      args: [],
    );
  }

  /// `During the database upgrade, please do not exit the app or leave this page.`
  String get upgrade_db_tips {
    return Intl.message(
      'During the database upgrade, please do not exit the app or leave this page.',
      name: 'upgrade_db_tips',
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
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}

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

  /// `Click this button for connect`
  String get click_connect {
    return Intl.message(
      'Click this button for connect',
      name: 'click_connect',
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

  /// `Please save and backup your seed safetly. Do not transfer via the internet. If you lose it you will lose access to your assets.`
  String get seed_qrcode_dec {
    return Intl.message(
      'Please save and backup your seed safetly. Do not transfer via the internet. If you lose it you will lose access to your assets.',
      name: 'seed_qrcode_dec',
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

  /// `Select Asset to Backup`
  String get select_asset_to_backup {
    return Intl.message(
      'Select Asset to Backup',
      name: 'select_asset_to_backup',
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
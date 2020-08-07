import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'messages_all.dart';

class NMobileLocalizations {
  static Future<NMobileLocalizations> load(Locale locale) {
    final String name = locale.countryCode?.isNotEmpty ?? false ? locale.toString() : locale.languageCode;
    final String localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      return NMobileLocalizations();
    });
  }

  static NMobileLocalizations of(BuildContext context) {
    return Localizations.of<NMobileLocalizations>(context, NMobileLocalizations);
  }

  String get nkn {
    return Intl.message('NKN', name: 'nkn', desc: '');
  }

  String get eth {
    return Intl.message('ETH', name: 'eth', desc: '');
  }

  String get gwei {
    return Intl.message('GWEI', name: 'gwei', desc: '');
  }

  String get gas_price {
    return Intl.message('Gas Price', name: 'gas_price', desc: '');
  }

  String get gas_max {
    return Intl.message('Max Gas', name: 'gas_max', desc: '');
  }

  String get loading {
    return Intl.message('Loading', name: 'loading', desc: '');
  }

  String get connecting {
    return Intl.message('Connecting', name: 'connecting', desc: '');
  }

  String get connected {
    return Intl.message('Connected', name: 'connected', desc: '');
  }

  String get click_connect {
    return Intl.message('Click this button for connect', name: 'click_connect', desc: '');
  }

  String get connect {
    return Intl.message('Connect', name: 'connect', desc: '');
  }

  String get ok {
    return Intl.message('OK', name: 'ok', desc: '');
  }

  String get done {
    return Intl.message('Done', name: 'done', desc: '');
  }

  String get close {
    return Intl.message('Close', name: 'close', desc: '');
  }

  String get cancel {
    return Intl.message('Cancel', name: 'cancel', desc: '');
  }

  String get yes {
    return Intl.message('Yes', name: 'yes', desc: '');
  }

  String get no {
    return Intl.message('No', name: 'no', desc: '');
  }

  String get warning {
    return Intl.message('Warning', name: 'warning', desc: '');
  }

  String get continue_text {
    return Intl.message('Continue', name: 'continue_text', desc: '');
  }

  String get accept_invitation {
    return Intl.message('Accept Invitation', name: 'accept_invitation', desc: '');
  }

  String get channel_invitation {
    return Intl.message('group invitation', name: 'channel_invitation', desc: '');
  }

  String get save {
    return Intl.message('Save', name: 'save', desc: '');
  }

  String get save_to_album {
    return Intl.message('Save To Album', name: 'save_to_album', desc: '');
  }

  String get max {
    return Intl.message('Max', name: 'max', desc: '');
  }

  String get min {
    return Intl.message('Min', name: 'min', desc: '');
  }

  String get slow {
    return Intl.message('Slow', name: 'slow', desc: '');
  }

  String get average {
    return Intl.message('Average', name: 'average', desc: '');
  }

  String get fast {
    return Intl.message('Fast', name: 'fast', desc: '');
  }

  String get copy {
    return Intl.message('Copy', name: 'copy', desc: '');
  }

  String get copy_success {
    return Intl.message('Copied to Clipboard', name: 'copy_success', desc: '');
  }

  String get invitation_sent {
    return Intl.message('Invitation sent', name: 'invitation_sent', desc: '');
  }

  String get success {
    return Intl.message('Success', name: 'success', desc: '');
  }

  String get copied {
    return Intl.message('Copied', name: 'copied', desc: '');
  }

  String get copy_to_clipboard {
    return Intl.message('Copy to Clipboard', name: 'copy_to_clipboard', desc: '');
  }

  String get rename {
    return Intl.message('Rename', name: 'rename', desc: '');
  }

  String get edit {
    return Intl.message('Edit', name: 'edit', desc: '');
  }

  String get edit_name {
    return Intl.message('Edit Name', name: 'edit_name', desc: '');
  }

  String get edit_nickname {
    return Intl.message('Edit Nickname', name: 'edit_nickname', desc: '');
  }

  String get input_nickname {
    return Intl.message('Please input Nickname', name: 'input_nickname', desc: '');
  }

  String get input_pubKey {
    return Intl.message('Please input Public Key', name: 'input_pubKey', desc: '');
  }

  String get input_name {
    return Intl.message('Please input Name', name: 'input_name', desc: '');
  }

  String get input_wallet_address {
    return Intl.message('Please input Wallet Address', name: 'input_wallet_address', desc: '');
  }

  String get input_notes {
    return Intl.message('Please input Notes', name: 'input_notes', desc: '');
  }

  String get edit_notes {
    return Intl.message('Edit Notes', name: 'edit_notes', desc: '');
  }

  String get view_all {
    return Intl.message('View All', name: 'view_all', desc: '');
  }

  String get latest_transactions {
    return Intl.message('Latest Transactions', name: 'latest_transactions', desc: '');
  }

  String get day {
    return Intl.message('day', name: 'day', desc: '');
  }

  String get today {
    return Intl.message('Today', name: 'today', desc: '');
  }

  String get delete {
    return Intl.message('Delete', name: 'delete', desc: '');
  }

  String get notes {
    return Intl.message('Notes', name: 'notes', desc: '');
  }

  String get none {
    return Intl.message('None', name: 'none', desc: '');
  }

  String get failure {
    return Intl.message('Failure', name: 'failure', desc: '');
  }

  String get title {
    return Intl.message('nMobile', name: 'title', desc: '');
  }

  String get send {
    return Intl.message('Send', name: 'send', desc: '');
  }

  String get send_nkn {
    return Intl.message('Send NKN', name: 'send_nkn', desc: '');
  }

  String get send_eth {
    return Intl.message('Send Eth', name: 'send_eth', desc: '');
  }

  String get receive {
    return Intl.message('Receive', name: 'receive', desc: '');
  }

  String get keystore {
    return Intl.message('Keystore', name: 'keystore', desc: '');
  }

  String get seed {
    return Intl.message('Seed', name: 'seed', desc: '');
  }

  String get private_key {
    return Intl.message('Private Key', name: 'private_key', desc: '');
  }

  String get public_key {
    return Intl.message('Public Key', name: 'public_key', desc: '');
  }

  String get my_wallets {
    return Intl.message('My Wallets', name: 'my_wallets', desc: '');
  }

  String get my_details {
    return Intl.message('My Details', name: 'my_details', desc: '');
  }

  String get mainnet {
    return Intl.message('MAINNET', name: 'mainnet', desc: '');
  }

  String get nkn_mainnet {
    return Intl.message('NKN Mainnet', name: 'nkn_mainnet', desc: '');
  }

  String get ethereum {
    return Intl.message('Ethereum', name: 'ethereum', desc: '');
  }

  String get ERC_20 {
    return Intl.message('ERC-20', name: 'ERC_20', desc: '');
  }

  String get wallet_name {
    return Intl.message('Wallet Name', name: 'wallet_name', desc: '');
  }

  String get wallet_address {
    return Intl.message('Wallet Address', name: 'wallet_address', desc: '');
  }

  String get wallet_password {
    return Intl.message('Password', name: 'wallet_password', desc: '');
  }

  String get wallet_password_mach {
    return Intl.message('Your password must be at least 8 characters. It is recommended to use a mix of different characters.', name: 'wallet_password_mach', desc: '');
  }

  String get wallet_password_helper_text {
    return Intl.message('Your password must be at least 8 characters. It is recommended to use a mix of different characters.', name: 'wallet_password_helper_text', desc: '');
  }

  String get wallet_password_error {
    return Intl.message('Your password must be at least 8 characters. It is recommended to use a mix of different characters.', name: 'wallet_password_error', desc: '');
  }

  String get password_wrong {
    return Intl.message('Wallet password or keystore file is wrong.', name: 'password_wrong', desc: '');
  }

  String get confirm_password {
    return Intl.message('Confirm Password', name: 'confirm_password', desc: '');
  }

  String get create {
    return Intl.message('Create', name: 'create', desc: '');
  }

  String get create_wallet {
    return Intl.message('Create Wallet', name: 'create_wallet', desc: '');
  }

  String get save_contact {
    return Intl.message('Save Contact', name: 'save_contact', desc: '');
  }

  String get delete_wallet {
    return Intl.message('Delete Wallet', name: 'delete_wallet', desc: '');
  }

  String get delete_wallet_confirm_title {
    return Intl.message('Are you sure you want to delete this wallet?', name: 'delete_wallet_confirm_title', desc: '');
  }

  String get delete_wallet_confirm_text {
    return Intl.message('This will remove the wallet off your local device. Please make sure your wallet is fully backed up or you will lose your funds.', name: 'delete_wallet_confirm_text', desc: '');
  }

  String get delete_message_confirm_title {
    return Intl.message('Are you sure you want to delete this message?', name: 'delete_message_confirm_title', desc: '');
  }

  String get delete_contact_confirm_title {
    return Intl.message('Are you sure you want to delete this contact?', name: 'delete_contact_confirm_title', desc: '');
  }

  String get delete_friend_confirm_title {
    return Intl.message('Are you sure you want to delete this friend?', name: 'delete_friend_confirm_title', desc: '');
  }

  String get leave_group_confirm_title {
    return Intl.message('Are you sure you want to leave this group?', name: 'leave_group_confirm_title', desc: '');
  }

  String get delete_cache_confirm_title {
    return Intl.message('Are you sure you want to delete cache?', name: 'delete_cache_confirm_title', desc: '');
  }

  String get delete_db_confirm_title {
    return Intl.message('Are you sure you want to clear the database?', name: 'delete_db_confirm_title', desc: '');
  }

  String get click_to_settings {
    return Intl.message('Click to settings', name: 'click_to_settings', desc: '');
  }

  String get import_wallet {
    return Intl.message('Import Wallet', name: 'import_wallet', desc: '');
  }

  String get export_wallet {
    return Intl.message('Export Wallet', name: 'export_wallet', desc: '');
  }

  String get view_channel_members {
    return Intl.message('Members', name: 'view_channel_members', desc: '');
  }

  String get invite_members {
    return Intl.message('Invite Members', name: 'invite_members', desc: '');
  }

  String get total_balance {
    return Intl.message('TOTAL BALANCE', name: 'total_balance', desc: '');
  }

  String get main_wallet {
    return Intl.message('Main Wallet', name: 'main_wallet', desc: '');
  }

  String get eth_wallet {
    return Intl.message('Eth Wallet', name: 'eth_wallet', desc: '');
  }

  String get view_qrcode {
    return Intl.message('View QR Code', name: 'view_qrcode', desc: '');
  }

  String get qrcode {
    return Intl.message('QR Code', name: 'qrcode', desc: '');
  }

  String get verify_wallet_password {
    return Intl.message('Verify Wallet Password', name: 'verify_wallet_password', desc: '');
  }

  String get seed_qrcode_dec {
    return Intl.message('Please save and backup your seed safetly. Do not transfer via the internet. If you lose it you will lose access to your assets.', name: 'seed_qrcode_dec', desc: '');
  }

  String get to {
    return Intl.message('To', name: 'to', desc: '');
  }

  String get send_to {
    return Intl.message('Send To', name: 'send_to', desc: '');
  }

  String get from {
    return Intl.message('From', name: 'from', desc: '');
  }

  String get fee {
    return Intl.message('Fee', name: 'fee', desc: '');
  }

  String get amount {
    return Intl.message('Amount', name: 'amount', desc: '');
  }

  String get enter_amount {
    return Intl.message('Enter amount', name: 'enter_amount', desc: '');
  }

  String get available {
    return Intl.message('Available', name: 'available', desc: '');
  }

  String get enter_first_name {
    return Intl.message('Enter first name', name: 'enter_first_name', desc: '');
  }

  String get enter_last_name {
    return Intl.message('Enter last name', name: 'enter_last_name', desc: '');
  }

  String get enter_users_address {
    return Intl.message('Enter users address', name: 'enter_users_address', desc: '');
  }

  String get enter_receive_address {
    return Intl.message('Enter receive address', name: 'enter_receive_address', desc: '');
  }

  String get enter_topic {
    return Intl.message('Enter topic', name: 'enter_topic', desc: '');
  }

  String get select_asset_to_send {
    return Intl.message('Select Asset to Send', name: 'select_asset_to_send', desc: '');
  }

  String get select_asset_to_receive {
    return Intl.message('Select Asset to Receive', name: 'select_asset_to_receive', desc: '');
  }

  String get select_another_wallet {
    return Intl.message('Select Another Wallet', name: 'select_another_wallet', desc: '');
  }

  String get select_wallet_type {
    return Intl.message('Select Wallet Type', name: 'select_wallet_type', desc: '');
  }

  String get select_wallet_type_desc {
    return Intl.message('Select whether to create a NKN Mainnet wallet or an Ethereum based wallet to hold ERC-20 tokens. The two are not compatible.',
        name: 'select_wallet_type_desc', desc: '',);
  }

  String get new_message {
    return Intl.message('New Message', name: 'new_message', desc: '');
  }

  String get you_have_new_message {
    return Intl.message('You have a new message', name: 'you_have_new_message', desc: '');
  }

  String get new_whisper {
    return Intl.message('Direct Message', name: 'new_whisper', desc: '');
  }

  String get new_group {
    return Intl.message('New Group', name: 'new_group', desc: '');
  }

  String get create_channel {
    return Intl.message('Create/Join to group', name: 'create_channel', desc: '');
  }

  String get private_channel {
    return Intl.message('Private Group', name: 'private_channel', desc: '');
  }

  String get private {
    return Intl.message('Private', name: 'private', desc: '');
  }

  String get channel_settings {
    return Intl.message('Group Settings', name: 'channel_settings', desc: '');
  }

  String get channel_members {
    return Intl.message('Group Members', name: 'channel_members', desc: '');
  }

  String get topic {
    return Intl.message('Topic', name: 'topic', desc: '');
  }

  String get address_book {
    return Intl.message('Address Book', name: 'address_book', desc: '');
  }

  String get popular_channels {
    return Intl.message('Popular Groups', name: 'popular_channels', desc: '');
  }

  String get my_group {
    return Intl.message('My Group', name: 'my_group', desc: '');
  }

  String get chat_settings {
    return Intl.message('D-Chat Settings', name: 'chat_settings', desc: '');
  }

  String get view_profile {
    return Intl.message('View Profile', name: 'view_profile', desc: '');
  }

  String get remark {
    return Intl.message('Remark', name: 'remark', desc: '');
  }

  String get contact {
    return Intl.message('Contact', name: 'contact', desc: '');
  }

  String get contacts {
    return Intl.message('Contacts', name: 'contacts', desc: '');
  }

  String get my_contact {
    return Intl.message('My Contact', name: 'my_contact', desc: '');
  }

  String get add_contact {
    return Intl.message('Add Contact', name: 'add_contact', desc: '');
  }

  String get edit_contact {
    return Intl.message('Edit Contact', name: 'edit_contact', desc: '');
  }

  String get delete_contact {
    return Intl.message('Delete Contact', name: 'delete_contact', desc: '');
  }

  String get stranger {
    return Intl.message('Stranger', name: 'stranger', desc: '');
  }

  String get recent {
    return Intl.message('Recently', name: 'recent', desc: '');
  }

  String get burn_after_reading {
    return Intl.message('Burn After Reading', name: 'burn_after_reading', desc: '');
  }

  String get pictures {
    return Intl.message('Pictures', name: 'pictures', desc: '');
  }

  String get camera {
    return Intl.message('Camera', name: 'camera', desc: '');
  }

  String get files {
    return Intl.message('Files', name: 'files', desc: '');
  }

  String get location {
    return Intl.message('Location', name: 'location', desc: '');
  }

  String get general {
    return Intl.message('General', name: 'general', desc: '');
  }

  String get featured {
    return Intl.message('Featured', name: 'featured', desc: '');
  }

  String get latest {
    return Intl.message('Latest', name: 'latest', desc: '');
  }

  String get language {
    return Intl.message('Language', name: 'language', desc: '');
  }

  String get security {
    return Intl.message('Security', name: 'security', desc: '');
  }

  String get face_id {
    return Intl.message('Face ID', name: 'face_id', desc: '');
  }

  String get touch_id {
    return Intl.message('Touch ID', name: 'touch_id', desc: '');
  }

  String get notification {
    return Intl.message('Notification', name: 'notification', desc: '');
  }

  String get local_notification {
    return Intl.message('Local Notification', name: 'local_notification', desc: '');
  }

  String get local_notification_only_name {
    return Intl.message('Only display name', name: 'local_notification_only_name', desc: '');
  }

  String get local_notification_both_name_message {
    return Intl.message('Display name and message', name: 'local_notification_both_name_message', desc: '');
  }

  String get local_notification_none_display {
    return Intl.message('None display', name: 'local_notification_none_display', desc: '');
  }

  String get notification_sound {
    return Intl.message('Notification Sound', name: 'notification_sound', desc: '');
  }

  String get advanced {
    return Intl.message('Advanced', name: 'advanced', desc: '');
  }

  String get clear_cache {
    return Intl.message('Clear Cache', name: 'clear_cache', desc: '');
  }

  String get clear_database {
    return Intl.message('Clear Database', name: 'clear_database', desc: '');
  }

  String get change_language {
    return Intl.message('Change Language', name: 'change_language', desc: '');
  }

  String get search {
    return Intl.message('Search', name: 'search', desc: '');
  }

  String get about {
    return Intl.message('About', name: 'about', desc: '');
  }

  String get app_version {
    return Intl.message('App Version', name: 'app_version', desc: '');
  }

  String get version {
    return Intl.message('Version', name: 'version', desc: '');
  }

  String get help {
    return Intl.message('Help', name: 'help', desc: '');
  }

  String get auto {
    return Intl.message('Auto', name: 'auto', desc: '');
  }

  String get me {
    return Intl.message('Me', name: 'me', desc: '');
  }

  String get client_address {
    return Intl.message('Client Address', name: 'client_address', desc: '');
  }

  String get name {
    return Intl.message('Name', name: 'name', desc: '');
  }

  String get first_name {
    return Intl.message('First Name', name: 'first_name', desc: '');
  }

  String get last_name {
    return Intl.message('Last Name', name: 'last_name', desc: '');
  }

  String get updated_at {
    return Intl.message('Updated at', name: 'updated_at', desc: '');
  }

  String get settings {
    return Intl.message('Settings', name: 'settings', desc: '');
  }

  String get members {
    return Intl.message('members', name: 'members', desc: '');
  }

  String get invites_desc_to {
    return Intl.message('Invites You to join group', name: 'invites_desc_to', desc: '');
  }

  String get accept {
    return Intl.message('Accept', name: 'accept', desc: '');
  }

  String get accepted {
    return Intl.message('accepted', name: 'accepted', desc: '');
  }

  String get debug {
    return Intl.message('Debug', name: 'debug', desc: '');
  }

  String get subscribe {
    return Intl.message('Subscribe', name: 'subscribe', desc: '');
  }

  String get unsubscribe {
    return Intl.message('Leave', name: 'unsubscribe', desc: '');
  }

  String get menu_wallet {
    return Intl.message('Wallet', name: 'menu_wallet', desc: '');
  }

  String get menu_news {
    return Intl.message('News', name: 'menu_news', desc: '');
  }

  String get news_from {
    return Intl.message('by', name: 'news_from', desc: '');
  }

  String get menu_chat {
    return Intl.message('D-Chat', name: 'menu_chat', desc: '');
  }

  String get menu_settings {
    return Intl.message('Settings', name: 'menu_settings', desc: '');
  }

  String get tab_seed {
    return Intl.message('Seed', name: 'tab_seed', desc: '');
  }

  String get tab_keystore {
    return Intl.message('Keystore', name: 'tab_keystore', desc: '');
  }

  String get no_wallet_title {
    return Intl.message('Keep your NKN organised', name: 'no_wallet_title', desc: '');
  }

  String get no_wallet_desc {
    return Intl.message('Manage both your Mainnet and ERC-20 NKN\n tokens with our smart wallet manager.', name: 'no_wallet_desc', desc: '');
  }

  String get no_wallet_create {
    return Intl.message('Create New Wallet', name: 'no_wallet_create', desc: '');
  }

  String get no_wallet_import {
    return Intl.message('Import Exisiting Wallet', name: 'no_wallet_import', desc: '');
  }

  String get create_nkn_wallet_title {
    return Intl.message('CREATE MAINNET WALLET', name: 'create_nkn_wallet_title', desc: '');
  }

  String get create_ethereum_wallet {
    return Intl.message('CREATE ETHEREUM WALLET', name: 'create_ethereum_wallet', desc: '');
  }

  String get import_keystore_nkn_wallet_title {
    return Intl.message('Import with Keystore', name: 'import_keystore_nkn_wallet_title', desc: '');
  }

  String get import_keystore_nkn_wallet_desc {
    return Intl.message('From your existing wallet, find out how to export keystore as well as associated password, make a backup of both, and then use both to import your existing wallet into nMobile.', name: 'import_keystore_nkn_wallet_desc', desc: '');
  }

  String get import_seed_nkn_wallet_title {
    return Intl.message('Import with Seed', name: 'import_seed_nkn_wallet_title', desc: '');
  }

  String get import_seed_nkn_wallet_desc {
    return Intl.message('From your existing wallet, find out how to export Seed (also called "Secret Seed"), make a backup copy, and then use it to import your existing wallet into nMobile.', name: 'import_seed_nkn_wallet_desc', desc: '');
  }

  String get error_required {
    return Intl.message('This field is required.', name: 'error_required', desc: '');
  }

  String error_field_required(String field) {
    return Intl.message('$field is required.', name: 'error_field_required', desc: '', args: [field]);
  }

  String get error_confirm_password {
    return Intl.message('Password does not match.', name: 'error_confirm_password', desc: '');
  }

  String get error_keystore_format {
    return Intl.message('Keystore format does not match.', name: 'error_keystore_format', desc: '');
  }

  String get error_seed_format {
    return Intl.message('Seed format does not match.', name: 'error_seed_format', desc: '');
  }

  String get error_client_address_format {
    return Intl.message('Client address format does not match.', name: 'error_client_address_format', desc: '');
  }

  String get error_nkn_address_format {
    return Intl.message('Invalid wallet address.', name: 'error_nkn_address_format', desc: '');
  }

  String get error_unknown_nkn_qrcode {
    return Intl.message('Unknown NKN qr code.', name: 'error_unknown_nkn_qrcode', desc: '');
  }

  String get chat_no_wallet_title {
    return Intl.message('Private and Secure\n Messaging', name: 'chat_no_wallet_title', desc: '');
  }

  String get chat_no_wallet_desc {
    return Intl.message('You need a Mainnet compatible wallet before you can use D-Chat.', name: 'chat_no_wallet_desc', desc: '');
  }

  String get chat_tab_messages {
    return Intl.message('Messages', name: 'chat_tab_messages', desc: '');
  }

  String get chat_tab_channels {
    return Intl.message('Groups', name: 'chat_tab_channels', desc: '');
  }

  String get chat_tab_group {
    return Intl.message('Group', name: 'chat_tab_group', desc: '');
  }

  String get chat_no_messages_title {
    return Intl.message('Private and Secure\nMessaging', name: 'chat_no_messages_title', desc: '');
  }

  String get chat_no_messages_desc {
    return Intl.message('Start a new direct message or group chat, or join\nexisting ones..', name: 'chat_no_messages_desc', desc: '');
  }

  String get cantact_no_contact_title {
    return Intl.message('You haven’t got any\n contacts yet', name: 'cantact_no_contact_title', desc: '');
  }

  String get cantact_no_contact_desc {
    return Intl.message('Use your contact list to quickly message and\n send funds to your friends.', name: 'cantact_no_contact_desc', desc: '');
  }

  String get s {
    return Intl.message('s', name: 's', desc: '');
  }

  String get m {
    return Intl.message('m', name: 'm', desc: '');
  }

  String get h {
    return Intl.message('h', name: 'h', desc: '');
  }

  String get d {
    return Intl.message('d', name: 'd', desc: '');
  }

  String get update_burn_after_reading {
    return Intl.message('set the disappearing message timer', name: 'update_burn_after_reading', desc: '');
  }

  String get close_burn_after_reading {
    return Intl.message('disabled disappearing messages', name: 'close_burn_after_reading', desc: '');
  }

  String get joined_channel {
    return Intl.message('Joined group', name: 'joined_channel', desc: '');
  }

  String get burn_5_seconds {
    return Intl.message('5 seconds', name: 'burn_5_seconds', desc: '');
  }

  String get burn_10_seconds {
    return Intl.message('10 seconds', name: 'burn_10_seconds', desc: '');
  }

  String get burn_30_seconds {
    return Intl.message('30 seconds', name: 'burn_30_seconds', desc: '');
  }

  String get burn_1_minute {
    return Intl.message('1 minute', name: 'burn_1_minute', desc: '');
  }

  String get burn_5_minutes {
    return Intl.message('5 minutes', name: 'burn_5_minutes', desc: '');
  }

  String get burn_10_minutes {
    return Intl.message('10 minutes', name: 'burn_10_minutes', desc: '');
  }

  String get burn_30_minutes {
    return Intl.message('30 minutes', name: 'burn_30_minutes', desc: '');
  }

  String get burn_1_hour {
    return Intl.message('1 hour', name: 'burn_1_hour', desc: '');
  }

  String get burn_1_day {
    return Intl.message('1 day', name: 'burn_1_day', desc: '');
  }

  String get burn_1_week {
    return Intl.message('1 week', name: 'burn_1_week', desc: '');
  }

  String get hint_enter_wallet_name {
    return Intl.message('Enter wallet name', name: 'hint_enter_wallet_name', desc: '');
  }

  String get input_password {
    return Intl.message('Enter your local password', name: 'input_password', desc: '');
  }

  String get input_password_again {
    return Intl.message('Enter your password again', name: 'input_password_again', desc: '');
  }

  String get input_keystore {
    return Intl.message('Please paste keystore', name: 'input_keystore', desc: '');
  }

  String get input_seed {
    return Intl.message('Please input seed', name: 'input_seed', desc: '');
  }

  String get add_new_contact {
    return Intl.message('Add New Contact', name: 'add_new_contact', desc: '');
  }

  String get optional {
    return Intl.message('optional', name: 'optional', desc: '');
  }

  String get private_messages {
    return Intl.message('Private Messages', name: 'private_messages', desc: '');
  }

  String get private_messages_desc {
    return Intl.message('All direct messages are completely private and secure.', name: 'private_messages_desc', desc: '');
  }

  String get learn_more {
    return Intl.message('Learn More', name: 'learn_more', desc: '');
  }

  String get enter_or_select_a_user_pubkey {
    return Intl.message('Enter/Select a user D-Chat ID', name: 'enter_or_select_a_user_pubkey', desc: '');
  }

  String get scan_show_me_desc {
    return Intl.message('Scan the QR code pattern to add friends to your contacts.', name: 'scan_show_me_desc', desc: '');
  }

  String get nickname {
    return Intl.message('Nickname', name: 'nickname', desc: '');
  }

  String get d_chat_address {
    return Intl.message('D-Chat ID', name: 'd_chat_address', desc: '');
  }

  String get input_d_chat_address {
    return Intl.message('Please input D-Chat ID', name: 'input_d_chat_address', desc: '');
  }

  String get tip_password_error {
    return Intl.message('Wrong password', name: 'tip_password_error', desc: '');
  }

  String get type_a_message {
    return Intl.message('Type a message', name: 'type_a_message', desc: '');
  }

  String get placeholder_draft {
    return Intl.message('[Draft]', name: 'placeholder_draft', desc: '');
  }

  String get friends {
    return Intl.message('Friend', name: 'friends', desc: '');
  }

  String get group_chat {
    return Intl.message('Group', name: 'group_chat', desc: '');
  }

  String get d_chat_not_login {
    return Intl.message('D-Chat not login', name: 'd_chat_not_login', desc: '');
  }

  String get not_backed_up {
    return Intl.message('Not backed up yet', name: 'not_backed_up', desc: '');
  }

  String get d_not_backed_up_title {
    return Intl.message('Important: Please Back Up\n Your Wallets!', name: 'd_not_backed_up_title', desc: '');
  }

  String get d_not_backed_up_desc {
    return Intl.message('When you update your nMobile software or accidentally uninstall nMobile, your wallet might be lost and you might NOT be able to access your assets! So please take 3 minutes time now to back up all your wallets.', name: 'd_not_backed_up_desc', desc: '');
  }

  String get go_backup => Intl.message('Go Backup', name: 'go_backup');
  String get select_asset_to_backup => Intl.message('Select Asset to Backup', name: 'select_asset_to_backup');
  String get create_account => Intl.message('Create Account', name: 'create_account');
  String get import_wallet_as_account => Intl.message('Import Wallet as Account', name: 'import_wallet_as_account');

  String get transfer_initiated => Intl.message('Transfer Initiated', name: 'transfer_initiated');
  String get transfer_initiated_desc => Intl.message('Your transfer is in progress. It could take a few seconds to appear on the blockchain.', name: 'transfer_initiated_desc');
  String get tip => Intl.message('Tips', name: 'tip');
  String get my_details_desc => Intl.message('All subscriptions and tipping will come from your selected wallet.', name: 'my_details_desc');

  String get change_default_chat_wallet => Intl.message('Change', name: 'change_default_chat_wallet');
  String get coming_soon => Intl.message('Coming Soon...', name: 'coming_soon');
  String get my_profile => Intl.message('My Profile', name: 'my_profile');
  String get profile => Intl.message('Profile', name: 'profile');
  String get send_message => Intl.message('Send Message', name: 'send_message');
  String get show_wallet_address_desc => Intl.message('Scan the QR code, you can transfer it to me', name: 'show_wallet_address_desc');
  String get disappear_desc => Intl.message('Messages received and sent will disappear after the set time.', name: 'disappear_desc');

  String get account_switching_completed => Intl.message('Account switching Completed', name: 'account_switching_completed');
  String get storage_text => Intl.message('Storage', name: 'storage_text');

  String get export => Intl.message('Export', name: 'export');
  String get eth_keystore_export_desc => Intl.message('The current version does not support ERC20 Token transactions. Please export this wallet keystore for backup immediately.', name: 'eth_keystore_export_desc');
  String get you => Intl.message('You', name: 'you');
  String get seconds => Intl.message('seconds', name: 'seconds');
  String get hours => Intl.message('hours', name: 'hours');
  String get minute => Intl.message('minute', name: 'minute');
  String get week => Intl.message('week', name: 'week');

  String get select => Intl.message('Select', name: 'select');
  String get top => Intl.message('top', name: 'top');
}

class NMobileLocalizationsDelegate extends LocalizationsDelegate<NMobileLocalizations> {
  const NMobileLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<NMobileLocalizations> load(Locale locale) {
    return NMobileLocalizations.load(locale);
  }

  @override
  bool shouldReload(NMobileLocalizationsDelegate old) => false;
}

/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:nmobile/model/data/dchat_account.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// @author Chenai
/// @version 1.0, 03/07/2020
abstract class AccountDependsBloc /* extends Bloc<AccountEvent, DChatAccount>*/ {
  static DChatAccount _account;
  static ContactSchema _accountUser;
  static Set<AccountDependsBloc> _instances = HashSet();

  @protected
  registerObserver() {
    _instances.add(this);
  }

  @protected
  unregisterObserver() {
    _instances.remove(this);
  }

  DChatAccount get account => _account;

  Future<Database> get db => _account.dbHolder.db;

  String get accountPubkey => _account.client.pubkey;

  String get accountChatId => _account.client.myChatId;

  Future<ContactSchema> get accountUser => ContactSchema.getContactByAddress(db, accountChatId);

  bool isAccountValid() {
    return account != null && !account.client.isSeedMocked;
  }

// Not needed, can override this instead.
//  ```dart
//  @override
//  void onAccountChanged(DChatAccount account) {
//    setState(() {
//      ...
//    });
//  }
//  ```
//  BlocBuilder<> accountUserBuilderxxx() {
//    return null;
//  }

  FutureBuilder<ContactSchema> accountUserBuilder({
    @required Widget onUser(BuildContext context, ContactSchema user),
    Widget onWaiting(BuildContext context),
    Widget onError(BuildContext context, dynamic data),
  }) {
    return FutureBuilder(
        future: accountUser,
        initialData: _accountUser,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _accountUser = snapshot.data;
            return onUser(context, snapshot.data);
          } else {
            return snapshot.hasError
                ? (onError == null ? Padding(padding: EdgeInsets.all(0)) : onError(context, snapshot.error))
                : (onWaiting == null ? Padding(padding: EdgeInsets.all(0)) : onWaiting(context));
          }
        });
  }

  void changeAccount(DChatAccount account, {bool force = false}) {
    if (force || _account == null || _account.client.myChatId != account.client.myChatId) {
      // don't close it.
      // _account?.dbHolder?.close();
      _account = account;
      _accountUser = null;
      _notifyOnAccountChanged();
    }
  }

  void cacheAccountUser(ContactSchema user) {
    assert(user.clientAddress == accountChatId);
    _accountUser = user;
  }

  static _notifyOnAccountChanged() {
    for (var ins in _instances) {
      ins.onAccountChanged();
    }
  }

  void onAccountChanged() {}

//  @override
//  DChatAccount get initialState => null;
//
//  @override
//  Stream<DChatAccount> mapEventToState(AccountEvent event) async* {
//    _changeAccount(event.account);
//    yield event.account;
//  }
}

//class AccountEvent extends Equatable {
//  final DChatAccount account;
//
//  const AccountEvent(this.account) : assert(account != null);
//
//  @override
//  List<Object> get props => [account.clientProxy.dChatId];
//}

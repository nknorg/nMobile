/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'dart:collection';

/// @author Chenai
/// @version 1.0, 15/07/2020
typedef ActivePageCallback = void Function(bool);

class ActivePage {
  int _mindPageIndex;
  int _currActivePageIndex;

  ActivePage(this._mindPageIndex, [this._currActivePageIndex = -1]);

  bool get isCurrPageActive => _mindPageIndex == _currActivePageIndex;

  Set<ActivePageCallback> _observers = HashSet();

  addOnCurrPageActive(ActivePageCallback callback) {
    _observers.add(callback);
  }

  removeOnCurrPageActive(ActivePageCallback callback) {
    _observers.remove(callback);
  }

  setCurrActivePageIndex(int i) {
    _currActivePageIndex = i;
    _notifyObservers();
  }

  _notifyObservers() async {
    for (final callback in _observers) {
      callback(isCurrPageActive);
    }
  }
}

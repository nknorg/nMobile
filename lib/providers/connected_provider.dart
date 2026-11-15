import 'package:flutter_riverpod/legacy.dart';

class ConnectedNotifier extends StateNotifier<bool> {
  ConnectedNotifier() : super(false);

  void setConnected(bool value) {
    if (state != value) state = value;
  }
}

final connectedProvider = StateNotifierProvider<ConnectedNotifier, bool>((ref) {
  return ConnectedNotifier();
});



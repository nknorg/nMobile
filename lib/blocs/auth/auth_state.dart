import 'package:nmobile/model/entity/contact.dart';

abstract class AuthState {
  const AuthState();
}

class AuthFailState extends AuthState {
  const AuthFailState();
}

class AuthToUserState extends AuthState {
  final ContactSchema currentUser;
  const AuthToUserState(this.currentUser);
}

class AuthToFrontState extends AuthState {
  final ContactSchema currentUser;
  const AuthToFrontState(this.currentUser);
}

class AuthToBackgroundState extends AuthState {
  const AuthToBackgroundState();
}

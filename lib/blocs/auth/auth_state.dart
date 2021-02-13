
import 'package:nmobile/schemas/contact.dart';

abstract class AuthState {
  const AuthState();
}

class AuthFailState extends AuthState {
  const AuthFailState();
}

class AuthToUserState extends AuthState{
  final ContactSchema currentUser;
  // final String publicKey;
  // final String walletAddress;
  const AuthToUserState(this.currentUser);
}

class AuthToFrontState extends AuthState{

  final ContactSchema currentUser;
  const AuthToFrontState(this.currentUser);
}

class AuthToBackgroundState extends AuthState{
  const AuthToBackgroundState();
}

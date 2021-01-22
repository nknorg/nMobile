
import 'package:nmobile/schemas/contact.dart';

abstract class AuthState {
  const AuthState();
}

class AuthSuccessState extends AuthState {
  const AuthSuccessState();
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
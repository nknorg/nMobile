
import 'package:nmobile/schemas/contact.dart';

abstract class AuthState {
  const AuthState();
}

class AuthedSuccessState extends AuthState {
  final bool success;
  const AuthedSuccessState(this.success);
}

class AuthToUserState extends AuthState{
  final ContactSchema currentUser;
  // final String publicKey;
  // final String walletAddress;
  const AuthToUserState(this.currentUser);
}

class AuthToUserFinishedState extends AuthState{

}
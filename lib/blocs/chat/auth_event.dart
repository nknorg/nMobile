abstract class AuthEvent {
  const AuthEvent();
}

class AuthSuccessEvent extends AuthEvent {
  const AuthSuccessEvent();
}

class AuthFailEvent extends AuthEvent{
  const AuthFailEvent();
}

class AuthToUserEvent extends AuthEvent{
  final String publicKey;
  final String walletAddress;
  const AuthToUserEvent(this.publicKey,this.walletAddress);
}

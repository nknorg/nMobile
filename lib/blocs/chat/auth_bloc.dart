import 'package:bloc/bloc.dart';
import 'package:nmobile/blocs/chat/auth_event.dart';
import 'package:nmobile/blocs/chat/auth_state.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/schemas/message.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  @override
  AuthState get initialState => AuthedSuccessState(false);

  @override
  Stream<AuthState> mapEventToState(AuthEvent event) async* {
    if (event is AuthSuccessEvent){
      yield* _mapAuthedState(true);
    }
    else if (event is AuthFailEvent){
      yield* _mapAuthedState(false);
    }
    else if (event is AuthToUserEvent){
      String publicKey = event.publicKey;
      String walletAddress = event.walletAddress;
      ContactSchema currentUser = await ContactSchema.fetchContactByAddress(event.publicKey);
      if (currentUser == null) {
        DateTime now = DateTime.now();
        currentUser = ContactSchema(
          type: ContactType.me,
          clientAddress: publicKey,
          nknWalletAddress: walletAddress,
          createdTime: now,
          updatedTime: now,
          profileVersion: uuid.v4(),
        );
        await currentUser.insertContact();
        Global.debugLog('AuthBlock insert current User'+currentUser.clientAddress);
      }
      else{
        Global.debugLog('AuthBloc find current User'+currentUser.clientAddress);
      }
      yield AuthToUserState(currentUser);
    }
    else if (event is AuthToUserFinishedEvent){
      yield AuthToUserFinishedState();
    }
  }

  Stream<AuthState> _mapAuthedState(bool auth) async* {
    yield AuthedSuccessState(auth);
  }
}

import 'package:bloc/bloc.dart';
import 'package:nmobile/blocs/auth/auth_event.dart';
import 'package:nmobile/blocs/auth/auth_state.dart';
import 'package:nmobile/model/datacenter/contact_data_center.dart';
import 'package:nmobile/model/entity/contact.dart';
import 'package:nmobile/model/entity/message.dart';
import 'package:nmobile/utils/nlog_util.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  @override
  AuthState get initialState => AuthFailState();

  @override
  Stream<AuthState> mapEventToState(AuthEvent event) async* {
    if (event is AuthFailEvent) {
      yield AuthFailState();
    } else if (event is AuthToFrontEvent) {
      ContactSchema currentUser = await ContactSchema.fetchCurrentUser();
      yield AuthToFrontState(currentUser);
    } else if (event is AuthToBackgroundEvent) {
      yield AuthToBackgroundState();
    } else if (event is AuthToUserEvent) {
      String publicKey = event.publicKey;
      String walletAddress = event.walletAddress;
      ContactSchema currentUser =
          await ContactSchema.fetchContactByAddress(event.publicKey);
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
        NLog.w('AuthBloc insert User___' + currentUser.clientAddress);
      }

      yield AuthToUserState(currentUser);
    }
  }
}

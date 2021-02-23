import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:nmobile/blocs/contact/contact_event.dart';
import 'package:nmobile/blocs/contact/contact_state.dart';
import 'package:nmobile/model/db/nkn_data_manager.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class ContactBloc extends Bloc<ContactEvent, ContactState> {
  @override
  ContactState get initialState => ContactNotLoad();

  @override
  Stream<ContactState> mapEventToState(ContactEvent event) async* {
    if (event is LoadContact) {
      yield* _mapLoadContactToState(event);
    }
    else if (event is UpdateUserInfoEvent){
      yield* _mapUpdateUserInfoState(event);
    }
    else if (event is LoadContactInfoEvent){
      yield* _mapLoadContactInfoState(event);
    }
  }

  Stream<ContactState> _mapLoadContactToState(LoadContact event) async* {
    var contacts = await _queryContactsByAddress(event.address);
    yield ContactLoaded(contacts);
  }

  Stream<ContactState> _mapUpdateUserInfoState(UpdateUserInfoEvent event) async* {
    ContactSchema contactSchema = event.userInfo;
    yield UpdateUserInfoState(contactSchema);
  }

  Stream<ContactState> _mapLoadContactInfoState(LoadContactInfoEvent event) async* {
    ContactSchema contactSchema = await ContactSchema.fetchContactByAddress(event.address);
    yield LoadContactInfoState(contactSchema);
  }


  Future<List<ContactSchema>> _queryContactsByAddress(List<String> address) async {
    List<ContactSchema> list = <ContactSchema>[];
    if (state is ContactLoaded) {
      list = List.from((state as ContactLoaded).contacts);
    }
    Database cdb = await NKNDataManager().currentDatabase();
    var contactsRes = await cdb.rawQuery('SELECT * FROM ${ContactSchema.tableName} WHERE address IN (${address.map((x) => '\'$x\'').join(',')})');
    List<ContactSchema> contacts = contactsRes.map((x) => ContactSchema.parseEntity(x)).toList();
    for (var i = 0, length = contactsRes.length; i < length; i++) {
      var item = contacts[i];
      var findIndex = list.indexWhere((x) => x.clientAddress == item.clientAddress);
      if (findIndex > -1) {
        list[findIndex].firstName = item.firstName;
        list[findIndex].lastName = item.lastName;
        list[findIndex].notes = item.notes;
        list[findIndex].avatar = item.avatar;
        list[findIndex].options = item.options;
        list[findIndex].sourceProfile = item.sourceProfile;
        list[findIndex].profileVersion = item.profileVersion;
        list[findIndex].profileExpiresAt = item.profileExpiresAt;
      } else {
        list.add(item);
      }
    }

    return list;
  }
}

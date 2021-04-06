import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:nmobile/blocs/contact/contact_event.dart';
import 'package:nmobile/blocs/contact/contact_state.dart';
import 'package:nmobile/model/datacenter/contact_data_center.dart';
import 'package:nmobile/model/entity/contact.dart';

class ContactBloc extends Bloc<ContactEvent, ContactState> {
  @override
  ContactState get initialState => ContactNotLoad();

  @override
  Stream<ContactState> mapEventToState(ContactEvent event) async* {
    if (event is LoadContact) {
      yield* _mapLoadContactToState(event);
    } else if (event is UpdateUserInfoEvent) {
      yield* _mapUpdateUserInfoState(event);
    } else if (event is LoadContactInfoEvent) {
      yield* _mapLoadContactInfoState(event);
    }
  }

  Stream<ContactState> _mapLoadContactToState(LoadContact event) async* {
    var contacts = await _queryContactsByAddress(event.address);
    yield ContactLoaded(contacts);
  }

  Stream<ContactState> _mapUpdateUserInfoState(
      UpdateUserInfoEvent event) async* {
    ContactSchema contactSchema = event.userInfo;
    yield UpdateUserInfoState(contactSchema);
  }

  Stream<ContactState> _mapLoadContactInfoState(
      LoadContactInfoEvent event) async* {
    ContactSchema contactSchema =
        await ContactSchema.fetchContactByAddress(event.address);
    yield LoadContactInfoState(contactSchema);
  }

  Future<List<ContactSchema>> _queryContactsByAddress(
      List<String> addressList) async {
    List<ContactSchema> savedList = <ContactSchema>[];
    if (state is ContactLoaded) {
      savedList = List.from((state as ContactLoaded).contacts);
    }

    /// Use this to set memory cache of contacts query
    List<String> cutAddressList = List<String>();
    for (String address in addressList){
      bool needAdd = true;
      for (ContactSchema mContact in savedList){
        if (address == mContact.clientAddress){
          needAdd = false;
          break;
        }
      }
      if (needAdd){
        cutAddressList.add(address);
      }
    }

    List<ContactSchema> contacts = await ContactDataCenter.findAllContactsByAddressList(addressList);
    if (savedList.isNotEmpty){
      if (savedList != null){
        contacts.addAll(savedList);
      }
    }
    return contacts;
  }
}

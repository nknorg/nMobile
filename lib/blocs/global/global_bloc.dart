import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:nmobile/blocs/global/global_event.dart';
import 'package:nmobile/blocs/global/global_state.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_storage.dart';

class GlobalBloc extends Bloc<GlobalEvent, GlobalState> {
  @override
  GlobalState get initialState => GlobalUpdated();

  final LocalStorage _localStorage = LocalStorage();

  @override
  Stream<GlobalState> mapEventToState(GlobalEvent event) async* {
    if (event is UpdateLanguage) {
      yield* _mapUpdateGlobalState(event);
    }
  }

  Stream<GlobalState> _mapUpdateGlobalState(UpdateLanguage event) async* {
    Global.locale = event.lang;
    _setLanguage(event.lang);
    yield LocaleUpdated(event.lang);
  }

  Future _setLanguage(String lang) async {
    List<Future> futures = <Future>[];
    futures.add(_localStorage.set('${LocalStorage.SETTINGS_KEY}:${LocalStorage.LOCALE_KEY}', lang));
    await Future.wait(futures);
  }
}

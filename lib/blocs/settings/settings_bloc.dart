import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/storages/settings.dart';

import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc() : super(null);

  SettingsStorage _settingsStorage = SettingsStorage();
  @override
  Stream<SettingsState> mapEventToState(SettingsEvent event) async* {
    if (event is UpdateLanguage) {
      yield* _mapUpdateLanguageState(event);
    }
  }

  Stream<SettingsState> _mapUpdateLanguageState(UpdateLanguage event) async* {
    _setLanguage(event.lang);
    yield LocaleUpdated(event.lang);
  }

  Future _setLanguage(String lang) async {
    await _settingsStorage.setSettings(SettingsStorage.LOCALE_KEY, lang);
  }
}
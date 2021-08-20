import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/settings/settings_event.dart';
import 'package:nmobile/blocs/settings/settings_state.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/storages/settings.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc() : super(SettingsInitial());

  @override
  Stream<SettingsState> mapEventToState(SettingsEvent event) async* {
    if (event is UpdateLanguage) {
      yield* _mapUpdateLanguageState(event);
    }
  }

  Stream<SettingsState> _mapUpdateLanguageState(UpdateLanguage event) async* {
    Settings.locale = event.lang;
    _setLanguage(event.lang);
    yield LocaleUpdated(event.lang);
  }

  Future _setLanguage(String lang) async {
    await SettingsStorage.setSettings(SettingsStorage.LOCALE_KEY, lang);
  }
}

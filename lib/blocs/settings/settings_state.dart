abstract class SettingsState {
  const SettingsState();
}

class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

class LocaleUpdated extends SettingsState {
  final String locale;
  const LocaleUpdated(this.locale);
}

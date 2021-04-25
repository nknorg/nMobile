abstract class SettingsState {
  const SettingsState();
}

class LocaleUpdated extends SettingsState {
  final String locale;
  const LocaleUpdated(this.locale);
}
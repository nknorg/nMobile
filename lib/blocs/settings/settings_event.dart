abstract class SettingsEvent {
  const SettingsEvent();
}

class UpdateLanguage extends SettingsEvent {
  final String lang;
  const UpdateLanguage(this.lang);
}

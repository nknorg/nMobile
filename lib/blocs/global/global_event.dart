abstract class GlobalEvent {
  const GlobalEvent();
}

class UpdateLanguage extends GlobalEvent {
  final String lang;
  const UpdateLanguage(this.lang);
}

abstract class GlobalState {
  const GlobalState();
}

class GlobalUpdated extends GlobalState {}

class LocaleUpdated extends GlobalState {
  final String locale;
  const LocaleUpdated(this.locale);
}

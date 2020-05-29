class ThemeSkin {
  static const String DEFAULT = 'default';
  static const String nkn = 'nkn';
}

class ThemeSchema {
  String primaryColor;
  String backgroundColor;
  String fontColor;

  ThemeSchema({
    this.primaryColor,
    this.backgroundColor,
    this.fontColor,
  });
}

import 'dart:convert';

class OptionsSchema {
  int deleteAfterSeconds;
  int backgroundColor;
  int color;
  OptionsSchema({
    this.deleteAfterSeconds,
    this.backgroundColor,
    this.color,
  });

  String toJson() {
    Map<String, dynamic> map = {};
    if (deleteAfterSeconds != null) map['deleteAfterSeconds'] = deleteAfterSeconds;
    if (backgroundColor != null) map['backgroundColor'] = backgroundColor;
    if (color != null) map['color'] = color;
    return jsonEncode(map);
  }
}

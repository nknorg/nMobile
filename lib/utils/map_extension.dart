extension MapExtension on Map<String, dynamic> {
  sortByKey() {
    List keys = this.keys.toList()..sort();
    Map newMap = Map<String, dynamic>();
    for (String key in keys) {
      newMap[key] = this[key];
    }
    return newMap;
  }
}

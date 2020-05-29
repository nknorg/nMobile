class ChatUtil {
  static RegExp reg = new RegExp("@[^ \\s!-,/:-?\\[-^`{-~，。？！（）【】《》“”：；、]+");

  static List getFormatString(String str) {
    RegExp reg = new RegExp("@[^ \\s!-,/:-?\\[-^`{-~，。？！（）【】《》“”：；、]+");
    List result = [];
    if (str == null || str.length == 0) return result;
    if (str.contains(reg)) {
      if (str.indexOf("@") > 0) {
        String s = str.substring(0, str.indexOf("@"));
        result.add(s);
        str = str.substring(s.length, str.length);
      }

      List spp = str.split("@");
      String temp;

      for (String s in spp) {
        if (s.length == 0) continue;
        temp = "@$s";
        String s1 = temp.split(temp.replaceAll(reg, ''))[0];
        result.add(s1);
        String s2 = temp.replaceAll(reg, '');
        result.add(s2);
      }
    } else {
      result.add(str);
    }
    return result;
  }
}

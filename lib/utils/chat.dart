RegExp reg = new RegExp("@[^ \\s!-,/:-?\\[-^`{-~，。？！（）【】《》“”：；、]+");
RegExp emailReg = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");

List getChatFormatString(String str) {
  RegExp reg = new RegExp("@[^ \\s!-,/:-?\\[-^`{-~，。？！（）【】《》“”：；、]+");
  List result = [];
  if (str == null || str.length == 0 || str.contains('&status=approve')) return result;

  if (str.contains(reg) && !str.contains(emailReg)) {
    List spp = str.split(" ");

    if (spp.firstWhere((x) => x.toString().contains(emailReg), orElse: () => null) != null) {
      return result;
    }

    for (String s in spp) {
      result.add(s);
      result.add(" ");
    }
  } else {
    return result;
  }
  return result;
}

RegExp chatRegSpecial = new RegExp("@[^ \\s!-,/:-?\\[-^`{-~，。？！（）【】《》“”：；、]+");
RegExp chatRegEmail = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");

List<String> getChatFormatString(String? str) {
  List<String> result = [];
  if (str == null || str.length == 0 || str.contains('&status=approve')) return result;

  if (str.contains(chatRegSpecial) && !str.contains(chatRegEmail)) {
    List<String> spp = str.split(" ");

    // if (spp.firstWhere((x) => x.toString().contains(chatRegEmail), orElse: () => "") != "") {
    //   return result;
    // }

    for (String s in spp) {
      result.add(s);
      result.add(" ");
    }
    return result;
  }
  return result;
}

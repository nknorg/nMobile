import 'package:nmobile/utils/map_extension.dart';

class PrivateGroupOptionSchema {
  String groupId;
  String groupName;
  String? signature;

  PrivateGroupOptionSchema({
    required this.groupId,
    required this.groupName,
    this.signature,
  });

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {};
    map['data'] = Map<String, dynamic>();
    map['data']['groupId'] = groupId;
    map['data']['groupName'] = groupName;
    map['data'] = (map['data'] as Map<String, dynamic>).sortByKey();

    map['signature'] = signature;
    return map;
  }

  Map<String, dynamic> getData() {
    Map<String, dynamic> data = {};
    data = Map<String, dynamic>();
    data['groupId'] = groupId;
    data['groupName'] = groupName;
    data = data.sortByKey();

    return data;
  }

  static PrivateGroupOptionSchema fromMap(Map map) {
    PrivateGroupOptionSchema schema = PrivateGroupOptionSchema(groupId: map['groupId'], groupName: map['groupName'], signature: map['signature']);
    return schema;
  }
}

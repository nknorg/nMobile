import 'dart:convert';

import 'package:nmobile/common/chat/chat.dart';
import 'package:nmobile/schema/message.dart';

String createReceiptMessage(String msgId) {
  Map data = {
    'id': uuid.v4(),
    'contentType': ContentType.receipt,
    'targetID': msgId,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };
  return jsonEncode(data);
}

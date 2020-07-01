
class MessageStd {
  String id; // random uuid
  String contentType; // text/image/audio/video/event[:custom_action]/customize
  String content; // JSON
  // For compatible web version, it must be `null` for PRIVATE chat.
  String topic; // null/''/undefined for PRIVATE chat, ${arbitrary identifier}.${64 length hex pubkey} for PRIVATE GROUP chat, else PUBLIC GROUP chat.
  int timestamp;
  // for textExtension
  /*MessageOptions*/Map options;
}

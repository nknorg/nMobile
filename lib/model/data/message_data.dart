/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

/// @author Chenai
/// @version 1.0, 03/07/2020
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

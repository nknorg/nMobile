class Subscriber {
  final int id;
  final String topic;
  final String chatId;
  final int indexPermiPage;
  final int timeCreate;
  final int blockHeightExpireAt;
  final int memberStatus;

  const Subscriber({
    this.id,
    this.topic,
    this.chatId,
    this.indexPermiPage,
    this.timeCreate,
    this.blockHeightExpireAt,
    this.memberStatus,
  });
}

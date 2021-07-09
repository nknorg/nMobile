class Subscriber {
  final int? id;
  final String topic;
  final String clientAddress;
  final DateTime? createAt;
  final DateTime? updateAt;
  final int? expireBlockHeight;
  final int? memberStatus;
  final int? permPage;

  const Subscriber({
    this.id,
    required this.topic,
    required this.clientAddress,
    this.createAt,
    this.updateAt,
    this.expireBlockHeight,
    this.memberStatus,
    this.permPage,
  });
}

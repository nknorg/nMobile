import 'package:equatable/equatable.dart';
import 'package:nmobile/schemas/cdn_miner.dart';

abstract class CDNEvent extends Equatable {
  const CDNEvent();

  @override
  List<Object> get props => [];
}

class LoadData extends CDNEvent {
  final CdnMiner data;
  const LoadData({this.data});
}

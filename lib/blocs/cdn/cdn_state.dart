import 'package:nmobile/schemas/cdn_miner.dart';

abstract class CDNState {
  const CDNState();
}

class LoadSate extends CDNState {
  CdnMiner data;
  LoadSate(this.data);
}

class NormalSate extends CDNState {}

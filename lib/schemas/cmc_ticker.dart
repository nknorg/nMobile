import 'package:equatable/equatable.dart';

class CmcTickerSchema extends Equatable {
  String id;
  String name;
  String symbol;
  double price_usd;
  double price_btc;
  double percent_change_1h;
  double percent_change_24h;
  double percent_change_7d;

  CmcTickerSchema({
    this.id,
    this.name,
    this.symbol,
    this.price_usd,
    this.price_btc,
    this.percent_change_1h,
    this.percent_change_24h,
    this.percent_change_7d,
  });

  @override
  List<Object> get props => [id];

  @override
  String toString() => 'CmcTickerSchema { id: $id }';
}

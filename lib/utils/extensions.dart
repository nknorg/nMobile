import 'package:flutter/material.dart';

extension ParseNumbers on String {
  int parseInt() {
    return int.parse(this);
  }

  double parseDouble() {
    return double.parse(this);
  }
}

extension PaddingDouble on double {
  EdgeInsets pad() => EdgeInsets.all(this);

  EdgeInsets pal() => EdgeInsets.only(left: this);

  EdgeInsets par() => EdgeInsets.only(right: this);

  EdgeInsets pat() => EdgeInsets.only(top: this);

  EdgeInsets pab() => EdgeInsets.only(bottom: this);
}

extension PaddingInt on int {
  EdgeInsets pad() => EdgeInsets.all(this.toDouble());

  EdgeInsets pal() => EdgeInsets.only(left: this.toDouble());

  EdgeInsets pat() => EdgeInsets.only(top: this.toDouble());

  EdgeInsets par() => EdgeInsets.only(right: this.toDouble());

  EdgeInsets pab() => EdgeInsets.only(bottom: this.toDouble());
}

extension PaddingEdgeInsets on EdgeInsets {
  EdgeInsets pal(double value) => EdgeInsets.fromLTRB(value, this.top, this.right, this.bottom);

  EdgeInsets pat(double value) => EdgeInsets.fromLTRB(this.left, value, this.right, this.bottom);

  EdgeInsets par(double value) => EdgeInsets.fromLTRB(this.left, this.top, value, this.bottom);

  EdgeInsets pab(double value) => EdgeInsets.fromLTRB(this.left, this.top, this.right, value);
}

extension PaddingWidget on Widget {
  Padding padding(EdgeInsets padding) => Padding(padding: padding, child: this);
}

extension OffstageWidget on Widget {
  Widget offstage(bool b) => b ? Offstage(offstage: true, child: this) : this;
}

main() {
  // e.g.
  print('42'.parseInt());
}
